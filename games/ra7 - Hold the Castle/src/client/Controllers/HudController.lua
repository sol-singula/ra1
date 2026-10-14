--[[
The HUD (master plan §16: phone first, big buttons, no tiny icons): the clock and the three shrines at the top,
who you are (team, job, health, monster level) and what you carry on the left, coins and the menu on the right,
and in the middle the big moments: alerts, callouts ("Shrine 1 is falling!"), toasts and the floating numbers.
Also the screens that take over for a moment: the monster job picker, the first choice, the daily gift and the
end of the match. The action buttons are InputController's; the piece bar is BuildController's.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = { Name = "HudController", Order = 10 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui, modal
local refs = {}

local PHASES = {
	intermission = { icon = "🍺", label = "HANGOUT", color = C.teal },
	build = { icon = "🔨", label = "BUILD TIME", color = C.mustard },
	plague = { icon = "☠️", label = "THE PLAGUE!", color = Color3.fromRGB(150, 230, 70) },
	fight = { icon = "⚔️", label = "HOLD ON!", color = C.orange },
	laststand = { icon = "🔥", label = "LAST STAND", color = C.red },
	ended = { icon = "🏁", label = "MATCH OVER", color = C.purple },
}
local SHRINE_ICON = { "⛰️", "🏜️", "🕳️" }

-- Top: the clock and the shrines -----------------------------------------------------------------------------
local function buildTop()
	local slab = Theme.slab({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(380, 112),
		Parent = gui,
	})
	refs.phase = Theme.title({
		Name = "Phase",
		Text = "",
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = slab,
	})
	refs.sub = Theme.text({
		Name = "Sub",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = slab,
	})
	refs.shrines = {}
	for i = 1, 3 do
		local pip = new("Frame", {
			Name = "Shrine" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(116, 44),
			Position = UDim2.fromOffset(10 + (i - 1) * 122, 62),
			Parent = slab,
		})
		local label = Theme.text({
			Name = "Label",
			Text = SHRINE_ICON[i] .. " " .. MapLayout.shrines[i].short:upper(),
			TextColor3 = C.white,
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			outline = 1.5,
			Parent = pip,
		})
		local bar, fill =
			Theme.bar({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 20), Parent = pip }, C.teal)
		local count = Theme.text({
			Name = "Count",
			Text = "",
			TextColor3 = C.white,
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 34),
			TextXAlignment = Enum.TextXAlignment.Center,
			outline = 1,
			Parent = pip,
		})
		refs.shrines[i] = { frame = pip, label = label, bar = bar, fill = fill, count = count }
	end
end

local function updateTop()
	local phase = Store.phase()
	local spec = PHASES[phase] or PHASES.build
	local left = Store.timeLeft()
	local t = left and Formulas.clock(left) or ""
	refs.phase.Text = spec.icon
		.. " "
		.. spec.label
		.. (left and (phase ~= "plague" and phase ~= "ended") and ("  " .. t) or "")
	refs.phase.TextColor3 = spec.color
	local m = Store.get("match")
	local sub = ""
	if phase == "intermission" then
		sub = left and left > 0 and `Next match in {t}` or "Waiting for players..."
	elseif phase == "build" then
		sub = Store.team() == "dwarf" and "Build the castle! The plague comes when the clock hits 0." or "Build time"
	elseif phase == "plague" then
		sub = "Some dwarves are turning into monsters..."
	elseif phase == "fight" or phase == "laststand" then
		local active = m and m.active or 1
		sub = Store.team() == "monster" and `Take Shrine {active}!` or `Hold Shrine {active} until the clock runs out!`
	elseif phase == "ended" then
		local r = m and m.result
		sub = r and (r.winner == "dwarf" and "The dwarves held the castle!" or "The monsters took the castle!") or ""
	end
	refs.sub.Text = sub
	local shrines = Store.get("shrines") or {}
	local fallen = m and m.fallen or 0
	for i, pip in refs.shrines do
		local s = shrines[i]
		local health = s and s.health or 100
		local state = s and s.state or (i <= fallen and "fallen" or "safe")
		pip.fill.Size = UDim2.fromScale(math.clamp(health / 100, 0, 1), 1)
		local draining = state == "active" and s and (s.rate or 0) < 0
		pip.fill.BackgroundColor3 = state == "fallen" and C.muted or draining and C.red or C.teal
		pip.label.Text = (state == "fallen" and "✖ " or SHRINE_ICON[i] .. " ") .. MapLayout.shrines[i].short:upper()
		pip.label.TextColor3 = state == "active" and C.mustard or state == "fallen" and C.muted or C.white
		if
			state == "active"
			and s
			and ((s.monsters or 0) > 0 or (s.dwarves or 0) > 0)
			and (phase == "fight" or phase == "laststand")
		then
			pip.count.Text = `👹{s.monsters}  vs  🧔{s.dwarves}`
		elseif state == "active" and s and s.stage and s.stage ~= "camp" then
			pip.count.Text = s.stage == "castle" and "🏰 CASTLE" or "🏘️ TOWN"
		else
			pip.count.Text = state == "fallen" and "FALLEN"
				or (i == (m and m.active or 1) and Store.inMatch() and "next" or "")
		end
	end
end

-- Left: who you are, and what you carry --------------------------------------------------------------------------
local function buildCard()
	local slab = Theme.slab({
		Name = "Me",
		Position = UDim2.fromOffset(10, 120),
		Size = UDim2.fromOffset(236, 92),
		Parent = gui,
	})
	refs.meTitle = Theme.title({
		Name = "Who",
		Text = "",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 4),
		Parent = slab,
	})
	refs.hpBar, refs.hpFill =
		Theme.bar({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 36), Parent = slab }, C.good)
	refs.hpText = Theme.text({
		Name = "Hp",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 1.5,
		ZIndex = 3,
		Parent = refs.hpBar,
	})
	refs.meLine = Theme.text({
		Name = "Line",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 60),
		outline = 1.5,
		Parent = slab,
	})
	refs.card = slab
	-- the bag (dwarves)
	local bag = Theme.slab({
		Name = "Bag",
		Position = UDim2.fromOffset(10, 218),
		Size = UDim2.fromOffset(236, 64),
		Parent = gui,
	})
	refs.bag = bag
	refs.bagItems = {}
	for k, m in Pieces.MATERIALS do
		refs.bagItems[m.key] = Theme.title({
			Name = m.key,
			Text = m.icon .. " 0",
			Size = UDim2.fromOffset(72, 30),
			Position = UDim2.fromOffset(8 + (k - 1) * 74, 4),
			Parent = bag,
		})
	end
	refs.bagCap, refs.bagFill =
		Theme.bar({ Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 42), Parent = bag }, C.mustard)
	-- food and potions (tap to use)
	refs.food = Theme.button({
		Name = "Food",
		Text = "🍲 0",
		BackgroundColor3 = C.orange,
		Size = UDim2.fromOffset(72, 40),
		Position = UDim2.fromOffset(10, 288),
		Parent = gui,
	})
	refs.potion = Theme.button({
		Name = "Potion",
		Text = "🧪 0",
		BackgroundColor3 = C.pink,
		Size = UDim2.fromOffset(72, 40),
		Position = UDim2.fromOffset(88, 288),
		Parent = gui,
	})
	refs.food.Activated:Connect(function()
		Bus.Tap:Fire("food")
		Net.send("Use", "food")
	end)
	refs.potion.Activated:Connect(function()
		Bus.Tap:Fire("potion")
		Net.send("Use", "potion")
	end)
end

local function updateCard()
	local me = Store.get("me") or {}
	local job = me.job and Jobs.byKey[me.job]
	local team = me.team
	if not team then
		refs.meTitle.Text = "🍺 In the hangout"
		refs.meLine.Text = "The next match starts soon!"
	else
		local name = job and job.name:upper() or ""
		refs.meTitle.Text = (team == "monster" and "👹 " or "🧔 ") .. (job and job.icon .. " " or "") .. name
		refs.meTitle.TextColor3 = team == "monster" and Color3.fromRGB(190, 255, 110) or C.mustard
		if team == "monster" then
			local next = me.nextXp
			refs.meLine.Text = `Monster level {me.level or 1}`
				.. (next and `  ({math.floor(me.xp or 0)}/{next} XP)` or "  (max)")
		else
			local g = me.gear or {}
			refs.meLine.Text =
				`🛡️ {g.armor or 0}/3  ⚔️ {g.weapon or 0}/3   🏆 {me.stats and me.stats.built or 0} built`
		end
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum and team then
		local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
		refs.hpFill.Size = UDim2.fromScale(frac, 1)
		refs.hpFill.BackgroundColor3 = frac < Constants.TIRED_AT and C.red or frac < 0.6 and C.mustard or C.good
		refs.hpText.Text = `{math.ceil(hum.Health)} / {hum.MaxHealth}`
	else
		refs.hpFill.Size = UDim2.fromScale(1, 1)
		refs.hpText.Text = ""
	end
	local dwarf = team == "dwarf"
	refs.bag.Visible = dwarf
	refs.food.Visible = dwarf and (me.food or 0) > 0
	refs.potion.Visible = dwarf and (me.potions or 0) > 0
	refs.food.Text = `🍲 {me.food or 0}`
	refs.potion.Text = `🧪 {me.potions or 0}`
	local bag = Store.get("bag") or {}
	local total = 0
	for _, m in Pieces.MATERIALS do
		local n = bag[m.key] or 0
		total += n
		refs.bagItems[m.key].Text = m.icon .. " " .. n
	end
	local cap = bag.cap or Constants.BAG_CAP
	refs.bagFill.Size = UDim2.fromScale(math.clamp(total / cap, 0, 1), 1)
	refs.bagFill.BackgroundColor3 = total >= cap and C.red or C.mustard
end

-- Right: coins, level and the menu ---------------------------------------------------------------------------------
local function buildMenu()
	local chip = Theme.slab({
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(170, 40),
		round = true,
		Parent = gui,
	})
	refs.coins = Theme.title({
		Name = "Value",
		Text = "🪙 0",
		Size = UDim2.new(0.6, 0, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Parent = chip,
	})
	refs.level = Theme.title({
		Name = "Level",
		Text = "Lv 1",
		Size = UDim2.new(0.4, -12, 1, -10),
		Position = UDim2.new(0.6, 0, 0, 5),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.mustard,
		Parent = chip,
	})
	local items = {
		{ "shop", "🛒", "SHOP", C.sky },
		{ "tasks", "📋", "TASKS", C.good },
		{ "friends", "👋", "FRIENDS", C.pink },
		{ "settings", "⚙️", "MORE", C.muted },
	}
	refs.menu = {}
	for k, it in items do
		local b, dot = Theme.iconButton({
			Name = it[1],
			icon = it[2],
			label = it[3],
			color = it[4],
			Size = UDim2.fromOffset(62, 62),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10 - (k - 1) * 70, 0, 54),
			Parent = gui,
		})
		b.Activated:Connect(function()
			Bus.Tap:Fire(it[1])
			Bus.Open:Fire(it[1])
		end)
		refs.menu[it[1]] = { button = b, dot = dot }
	end
end

local function updateMenu()
	local p = Store.get("profile")
	if not p then
		return
	end
	refs.coins.Text = "🪙 " .. tostring(p.coins)
	refs.level.Text = "Lv " .. tostring(p.level)
	local tasksDot = p.gift and p.gift.ready
	refs.menu.tasks.dot.Visible = tasksDot == true
end

-- Messages --------------------------------------------------------------------------------------------------------
local toastY = 0
function HudController.toast(text, kind)
	local color = kind == "bad" and C.red or kind == "good" and C.good or C.slate
	local label = Theme.slab({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128 - toastY),
		Size = UDim2.fromOffset(440, 40),
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
	toastY = (toastY + 46) % 138
	Theme.pop(label)
	task.delay(3.2, function()
		label:Destroy()
	end)
end

function HudController.alert(text, color, seconds)
	if refs.alert then
		refs.alert:Destroy()
	end
	local label = Theme.title({
		Name = "Alert",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 0),
		Size = UDim2.fromOffset(760, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color or C.mustard,
		outline = 4,
		ZIndex = 20,
		Parent = gui,
	})
	refs.alert = label
	Theme.pop(label)
	task.delay(seconds or 2.6, function()
		if refs.alert == label then
			label:Destroy()
			refs.alert = nil
		end
	end)
end

local CALLOUT_COLOR = {
	falling = C.red,
	fallen = C.red,
	gate = C.orange,
	stage = C.good,
	scare = C.purple,
	scout = C.orange,
	last = C.mustard,
}
function HudController.callout(text, kind)
	if refs.callout then
		refs.callout:Destroy()
	end
	local slab = Theme.slab({
		Name = "Callout",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(520, 44),
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

-- Floating text in the world ("+2 🪨", "17", "You helped build this!").
local POPUP_COLOR = {
	good = C.good,
	bad = C.red,
	hit = Color3.fromRGB(255, 240, 120),
	info = C.white,
	gold = C.mustard,
	stone = Color3.fromRGB(220, 220, 230),
	wood = Color3.fromRGB(255, 200, 140),
}
function HudController.popup(position, text, kind)
	if typeof(position) ~= "Vector3" then
		return
	end
	local anchor = new("Part", {
		Name = "Popup",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace,
	})
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(kind == "good" and 260 or 160, 40),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 140,
		Parent = anchor,
	})
	local label = Theme.title({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = POPUP_COLOR[kind] or C.white,
		Parent = bb,
	})
	Theme.tween(anchor, 1.1, { CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) })
	task.delay(0.7, function()
		Theme.tween(label, 0.4, { TextTransparency = 1 })
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

-- Getting hit: red edges and a little number.
local function hurt(info)
	refs.vignette.ImageTransparency = 0.25
	refs.vignette.Visible = true
	Theme.tween(refs.vignette, 0.6, { ImageTransparency = 1 })
	Bus.Shake:Fire(math.clamp((info.amount or 5) / 30, 0.15, 0.8), 0.25)
end

local function flash(color, seconds)
	refs.flash.BackgroundColor3 = color or C.white
	refs.flash.BackgroundTransparency = 0.25
	refs.flash.Visible = true
	Theme.tween(refs.flash, seconds or 0.6, { BackgroundTransparency = 1 })
end

-- Screens that take over ---------------------------------------------------------------------------------------------
local function closeModal()
	if modal then
		modal:Destroy()
		modal = nil
	end
end

local function modalCard(name, size)
	closeModal()
	local back = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.45,
		ZIndex = 30,
		Parent = gui,
	})
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size,
		ZIndex = 31,
		Parent = back,
	})
	modal = back
	Theme.pop(card)
	return card, back
end

-- The monster job picker: five big cards, the locked ones say how to unlock them.
local function showPicker(data)
	if not data then
		if modal and modal.Name == "Picker" then
			closeModal()
		end
		return
	end
	local card = modalCard("Picker", UDim2.fromOffset(760, 330))
	Theme.title({
		Text = data.why == "plague" and "THE PLAGUE GOT YOU! PICK YOUR MONSTER"
			or data.why == "join" and "PICK YOUR MONSTER"
			or "YOU'RE A MONSTER NOW! PICK ONE",
		Size = UDim2.new(1, -30, 0, 40),
		Position = UDim2.fromOffset(15, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(150, 230, 70),
		ZIndex = 32,
		Parent = card,
	})
	refs.pickerTimer = Theme.text({
		Text = "",
		Size = UDim2.new(1, -30, 0, 22),
		Position = UDim2.fromOffset(15, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 32,
		Parent = card,
	})
	refs.pickerAt = data.respawnAt
	for k, j in data.jobs do
		local job = Jobs.byKey[j.key]
		local b = Theme.button({
			Name = j.key,
			Text = "",
			BackgroundColor3 = j.unlocked and (j.key == data.current and C.good or C.paper) or C.muted,
			dark = true,
			Size = UDim2.fromOffset(136, 220),
			Position = UDim2.fromOffset(16 + (k - 1) * 146, 82),
			ZIndex = 32,
			Parent = card,
		})
		Theme.text({
			Text = job.icon,
			Size = UDim2.new(1, 0, 0, 60),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 33,
			Parent = b,
		})
		Theme.text({
			Text = job.name:upper(),
			Font = Theme.Display,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 60),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 33,
			Parent = b,
		})
		Theme.text({
			Text = j.unlocked and job.line or `🔒 Monster level {job.unlock}`,
			TextSize = 14,
			Size = UDim2.new(1, -8, 0, 70),
			Position = UDim2.fromOffset(4, 88),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 33,
			Parent = b,
		})
		Theme.text({
			Text = job.special.icon .. " " .. job.special.name,
			TextSize = 13,
			Size = UDim2.new(1, -8, 0, 30),
			Position = UDim2.fromOffset(4, 160),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.purple,
			ZIndex = 33,
			Parent = b,
		})
		b.Activated:Connect(function()
			if j.unlocked then
				Bus.Tap:Fire("pick_" .. j.key)
				Net.send("Job", j.key)
				closeModal()
			end
		end)
	end
end

-- The first choice (§12, 1:00): three big buttons, one short line each.
local function showChoice(data)
	if not data then
		if modal and modal.Name == "Choice" then
			closeModal()
		end
		return
	end
	local card = modalCard("Choice", UDim2.fromOffset(640, 300))
	Theme.title({
		Text = "YOUR FIRST CHOICE!",
		Size = UDim2.new(1, -30, 0, 42),
		Position = UDim2.fromOffset(15, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		ZIndex = 32,
		Parent = card,
	})
	for k, opt in data.options do
		local b = Theme.button({
			Name = opt.key,
			Text = "",
			BackgroundColor3 = ({ C.sky, C.orange, C.good })[k],
			Size = UDim2.fromOffset(190, 210),
			Position = UDim2.fromOffset(18 + (k - 1) * 204, 66),
			ZIndex = 32,
			Parent = card,
		})
		Theme.text({
			Text = opt.icon,
			Size = UDim2.new(1, 0, 0, 80),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 33,
			Parent = b,
		})
		Theme.title({
			Text = opt.title:upper(),
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 86),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 33,
			Parent = b,
		})
		Theme.title({
			Text = opt.line,
			TextSize = 16,
			Size = UDim2.new(1, -10, 0, 60),
			Position = UDim2.fromOffset(5, 126),
			TextXAlignment = Enum.TextXAlignment.Center,
			outline = 1.5,
			ZIndex = 33,
			Parent = b,
		})
		b.Activated:Connect(function()
			Bus.Tap:Fire("choice_" .. opt.key)
			Net.send("Choice", k)
			closeModal()
		end)
	end
end

-- The end of the match: who won, how long the dwarves held, what you earned, who did the most.
local MVP_LINES = {
	{ "builder", "🔨 Best builder" },
	{ "defender", "🛡️ Most monsters beaten" },
	{ "monster", "👹 Scariest monster" },
	{ "healer", "💚 Best healer" },
	{ "lastDwarf", "🧔 Last dwarf standing" },
}
local function showResults(r)
	local card = modalCard("Results", UDim2.fromOffset(620, 380))
	local won = r.winner == "dwarf"
	Theme.title({
		Text = won and "🏰 THE DWARVES HELD!" or "👹 THE MONSTERS WON!",
		Size = UDim2.new(1, -30, 0, 50),
		Position = UDim2.fromOffset(15, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = won and C.mustard or Color3.fromRGB(150, 230, 70),
		ZIndex = 32,
		Parent = card,
	})
	Theme.text({
		Text = `Held for {Formulas.clock(r.held or 0)}  ·  {r.fallen or 0} of 3 shrines taken`,
		Font = Theme.Display,
		Size = UDim2.new(1, -30, 0, 26),
		Position = UDim2.fromOffset(15, 62),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 32,
		Parent = card,
	})
	local you = r.you or {}
	local st = you.stats or {}
	local lines = {
		you.won and "🎉 YOU WON!" or "Good fight!",
		`🪙 +{you.coins or 0} coins   ✨ +{you.xp or 0} XP`
			.. (you.leveledUp and `   ⬆️ Level {you.level}!` or ""),
		`🛠 {st.built or 0} built   ⚔️ {(st.beaten or 0) + (st.dwarvesBeaten or 0)} beaten   💥 {st.broken or 0} broken   ⏱ {Formulas.clock(
			st.heldSeconds or 0
		)} held`,
	}
	for k, line in lines do
		Theme.text({
			Text = line,
			Font = k == 1 and Theme.Display or Theme.Body,
			Size = UDim2.new(1, -30, 0, k == 1 and 30 or 24),
			Position = UDim2.fromOffset(15, 96 + (k - 1) * 32),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = k == 1 and (you.won and C.good or C.ink) or C.ink,
			ZIndex = 32,
			Parent = card,
		})
	end
	local y = 196
	for _, m in MVP_LINES do
		local who = r.mvps and r.mvps[m[1]]
		if who then
			Theme.text({
				Text = `{m[2]}: {who.name}` .. (who.n and ` ({who.n})` or ""),
				TextSize = 18,
				Size = UDim2.new(1, -60, 0, 24),
				Position = UDim2.fromOffset(30, y),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 32,
				Parent = card,
			})
			y += 26
		end
	end
	local ok = Theme.button({
		Text = "OK",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(160, 48),
		Position = UDim2.new(0.5, 0, 1, -14),
		ZIndex = 32,
		Parent = card,
	})
	ok.Activated:Connect(closeModal)
	task.delay(Constants.ENDED_SECONDS + 4, function()
		if modal and modal.Name == "Results" then
			closeModal()
		end
	end)
end

-- The daily gift, once a day when you join.
local giftShown = false
local function maybeGift()
	local p = Store.get("profile")
	if giftShown or not p or not p.gift or not p.gift.ready or modal then
		return
	end
	giftShown = true
	local card = modalCard("Gift", UDim2.fromOffset(420, 260))
	Theme.title({
		Text = "🎁 DAILY GIFT!",
		Size = UDim2.new(1, -30, 0, 46),
		Position = UDim2.fromOffset(15, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		ZIndex = 32,
		Parent = card,
	})
	Theme.text({
		Text = `Day {math.max(1, (p.gift.streak or 0) + 1)}: 🪙 {p.gift.next} coins for looks.\nCome back tomorrow for more!`,
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 32,
		Parent = card,
	})
	local b = Theme.button({
		Text = "CLAIM",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(180, 54),
		Position = UDim2.new(0.5, 0, 1, -16),
		ZIndex = 32,
		Parent = card,
	})
	b.Activated:Connect(function()
		Bus.Tap:Fire("gift")
		Net.send("ClaimGift")
		closeModal()
	end)
end

-- Waiting to come back (a monster) or to get up (a dwarf before the plague).
local function updateRespawn()
	local me = Store.get("me") or {}
	local at = me.respawnAt
	local left = at and (at - workspace:GetServerTimeNow()) or nil
	if left and left > 0 then
		refs.respawn.Visible = true
		refs.respawn.Text = (me.team == "monster" and "👹 Back in " or "Back up in ") .. math.ceil(left) .. "..."
	else
		refs.respawn.Visible = false
	end
	if refs.pickerTimer and refs.pickerTimer.Parent and refs.pickerAt then
		local l = math.max(0, refs.pickerAt - workspace:GetServerTimeNow())
		refs.pickerTimer.Text = l > 0 and `You come back in {math.ceil(l)}s (Grunt if you don't pick)`
			or "Coming back..."
	end
end

local lastPhase -- the phase banners show once, when the phase changes
function HudController:init()
	gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.vignette = new("ImageLabel", {
		Name = "Hurt",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png",
		ImageColor3 = C.red,
		ImageTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	refs.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	buildTop()
	buildCard()
	buildMenu()
	refs.respawn = Theme.title({
		Name = "Respawn",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(520, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})

	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", HudController.alert)
	Net.listen("Callout", HudController.callout)
	Net.listen("Popup", HudController.popup)
	Net.listen("Hurt", hurt)
	Net.listen("Picker", showPicker)
	Net.listen("Choice", showChoice)
	Net.listen("Results", showResults)
	Bus.Flash:Connect(flash)
	Bus.Open:Connect(function(name)
		if name == "picker" then
			local me = Store.get("me")
			if me and me.team == "monster" then
				local list = {}
				for _, j in Jobs.monster do
					table.insert(list, { key = j.key, unlocked = Formulas.jobUnlocked(j, me.level or 1, 0) })
				end
				showPicker({ jobs = list, current = me.job })
			end
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.profile then
			updateMenu()
			maybeGift()
		end
		if partial.me or partial.bag then
			updateCard()
		end
		if partial.match and partial.match.phase ~= lastPhase then
			local m = partial.match
			lastPhase = m.phase
			if m.phase == "plague" then
				HudController.alert("☠️ THE PLAGUE!", Color3.fromRGB(150, 230, 70), 3)
			elseif m.phase == "build" and m.number then
				HudController.alert("🔨 HELP BUILD THE CASTLE!", C.mustard, 3)
			elseif m.phase == "fight" then
				HudController.alert(
					Store.team() == "monster" and "👹 ATTACK THE CASTLE!" or "⚔️ HOLD THE CASTLE!",
					C.orange,
					3
				)
			elseif m.phase == "laststand" then
				HudController.alert("🔥 THE LAST STAND!", C.red, 3)
			end
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			updateTop()
			updateCard()
			updateRespawn()
		end
	end)
	updateTop()
	updateCard()
end

-- (tests)
HudController.refs = refs

return HudController

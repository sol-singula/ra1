-- Modal panels: pantry / drink picker, stats (level-up allocation), menu editor, tier upgrade and the
-- first-mutation choice. One panel is open at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Ingredients = require(ReplicatedStorage.Shared.Data.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)

local C = Theme.Color
local new = Theme.new

local PanelController = { Name = "PanelController", Order = 20 }

local gui
local open -- { frame, kind, refresh }

local function close()
	if open then
		open.frame:Destroy()
		open = nil
	end
end

local function panel(kind, title, size)
	close()
	local frame = Theme.card({
		Name = kind,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Parent = gui,
	})
	Theme.text({
		Text = title,
		Font = Theme.Display,
		TextColor3 = C.ketchup,
		Size = UDim2.new(1, -90, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		Parent = frame,
	})
	local x = Theme.button({
		Text = "✕",
		BackgroundColor3 = C.ketchup,
		TextColor3 = C.white,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -54, 0, 14),
		Parent = frame,
	})
	x.Activated:Connect(close)
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 1, -80),
		Parent = frame,
	})
	open = { frame = frame, kind = kind, body = body }
	return body
end

local function grid(body, cell)
	return new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
end

-- Pantry / drink picker ---------------------------------------------------------------------------------
local function picker(info)
	local isDrink = info.mode == "drink"
	local rows = math.ceil(#info.options / 4)
	local body = panel("Picker", isDrink and "POUR A DRINK" or "PANTRY", UDim2.fromOffset(620, 110 + rows * 74))
	grid(body, UDim2.fromOffset(136, 64))
	for i, id in info.options do
		local name, color
		if isDrink then
			name, color = Recipes.byId[id].name, Recipes.byId[id].color
		else
			name, color = Ingredients[id].name, Ingredients[id].color
		end
		local b = Theme.button({ Text = "", BackgroundColor3 = C.white, LayoutOrder = i, Parent = body })
		new("Frame", {
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = b,
		}, { Theme.corner(6), Theme.stroke(2) })
		Theme.text({
			Text = name,
			TextSize = 15,
			TextScaled = false,
			Size = UDim2.new(1, -4, 0, 30),
			Position = UDim2.fromOffset(2, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		b.Activated:Connect(function()
			close()
			Net.send("PantryPick", id)
		end)
	end
end

-- Stats --------------------------------------------------------------------------------------------------
local FEATURED = { "COOK_SPD", "STR", "REPAIR", "LUCK" } -- the mockup's four headline stats (§C5)

local function stats(showAll)
	local list = showAll and Progression.Stats or {}
	if not showAll then
		for _, code in FEATURED do
			table.insert(list, Progression.StatByCode[code])
		end
	end
	local body = panel("Stats", `LEVEL {Store.get("level") or 1}`, UDim2.fromOffset(520, 150 + #list * 56))
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local s = Store.state
	for i, stat in list do
		local row =
			new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, Parent = body })
		Theme.text({ Text = stat.name, Size = UDim2.new(0.6, 0, 0, 24), Parent = row })
		Theme.text({
			Text = stat.blurb,
			TextColor3 = C.muted,
			Size = UDim2.new(0.7, 0, 0, 18),
			Position = UDim2.fromOffset(0, 26),
			Parent = row,
		})
		local eff = s.effective and s.effective[stat.code] or 0
		local alloc = s.stats and s.stats[stat.code] or 0
		Theme.text({
			Text = `{eff}`,
			Font = Theme.Display,
			Size = UDim2.fromOffset(60, 30),
			Position = UDim2.new(1, -120, 0, 8),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		local plus = Theme.button({
			Text = "+",
			BackgroundColor3 = C.good,
			Size = UDim2.fromOffset(44, 40),
			Position = UDim2.new(1, -48, 0, 4),
			Parent = row,
		})
		plus.Visible = (s.statPoints or 0) > 0 and alloc < Progression.MAX_ALLOCATED_PER_STAT
		plus.Activated:Connect(function()
			Net.send("AllocateStat", stat.code)
		end)
	end
	local footer =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 99, Parent = body })
	Theme.text({
		Text = `{s.statPoints or 0} points to spend`,
		TextColor3 = C.teal,
		Size = UDim2.new(0.6, 0, 1, 0),
		Parent = footer,
	})
	local more = Theme.button({
		Text = showAll and "Fewer stats ▲" or "More stats ▼",
		BackgroundColor3 = C.paper,
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(1, -150, 0, 2),
		Parent = footer,
	})
	more.Activated:Connect(function()
		stats(not showAll)
	end)
	open.refresh = function()
		stats(showAll)
	end
end

-- Menu ---------------------------------------------------------------------------------------------------
local function menu(selected)
	local s = Store.state
	selected = selected or table.clone(s.menu or {})
	local slots = s.menuSlots or 4
	local body = panel("Menu", `MENU  {#selected}/{slots}`, UDim2.fromOffset(640, 470))
	grid(body, UDim2.fromOffset(190, 70))
	for i, id in Recipes.order do
		local recipe = Recipes.byId[id]
		local locked = recipe.unlock > (s.level or 1)
		local on = table.find(selected, id) ~= nil
		local b = Theme.button({
			Text = "",
			LayoutOrder = i,
			BackgroundColor3 = locked and Color3.fromRGB(200, 196, 190) or (on and C.mustard or C.white),
			Parent = body,
		})
		Theme.text({
			Text = recipe.name,
			TextSize = 16,
			TextScaled = false,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 4),
			Parent = b,
		})
		Theme.text({
			Text = locked and `🔒 Level {recipe.unlock}` or `{recipe.price} MB · {recipe.course}`,
			TextColor3 = C.muted,
			TextSize = 14,
			TextScaled = false,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 30),
			Parent = b,
		})
		b.Activated:Connect(function()
			if locked then
				return
			end
			local idx = table.find(selected, id)
			if idx then
				table.remove(selected, idx)
			elseif #selected < slots then
				table.insert(selected, id)
			else
				HudController:toast(`Your menu has {slots} slots. Remove a dish first.`, "bad")
				return
			end
			menu(selected)
		end)
	end
	local save = Theme.button({
		Text = "Save menu",
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.new(1, -180, 1, -54),
		Parent = open.frame,
	})
	save.Activated:Connect(function()
		Net.send("SetMenu", selected)
		close()
	end)
end

-- Upgrade ------------------------------------------------------------------------------------------------
local function upgrade()
	local s = Store.state
	local nextTier = s.nextTier
	local body = panel("Upgrade", "UPGRADE RESTAURANT", UDim2.fromOffset(520, 330))
	if not nextTier then
		Theme.text({
			Text = "You own the biggest restaurant in this build. More tiers are coming!",
			Size = UDim2.new(1, 0, 0, 60),
			Parent = body,
		})
		return
	end
	Theme.text({ Text = `{s.tierName} → {nextTier.name}`, Size = UDim2.new(1, 0, 0, 30), Parent = body })
	local lines = {
		`Seats: {s.seats} → {nextTier.seats}`,
		`Menu slots: {s.menuSlots} → {nextTier.menu}`,
		`New customers: Hippo-Spider, Chaos Gremlin, Bodybuilder Pigeon`,
		`Needs level {nextTier.level} and {nextTier.cost} MB`,
	}
	for i, line in lines do
		Theme.text({
			Text = line,
			TextColor3 = i == 4 and C.ketchup or C.ink,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 36 + i * 30),
			Parent = body,
		})
	end
	local go = Theme.button({
		Text = "🔨 UPGRADE!",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(0, 0, 1, -50),
		Parent = body,
	})
	go.Activated:Connect(function()
		Net.send("UpgradeTier")
		close()
	end)
end

-- First mutation -----------------------------------------------------------------------------------------
local function chooseMutation(choices)
	local body = panel("Mutation", "CHOOSE YOUR FIRST MUTATION", UDim2.fromOffset(760, 380))
	open.frame:FindFirstChildWhichIsA("TextButton").Visible = false -- this choice can't be skipped
	grid(body, UDim2.fromOffset(226, 280))
	for i, id in choices do
		local m = Progression.Mutations[id]
		local card = Theme.card({ BackgroundColor3 = C.white, LayoutOrder = i, Parent = body })
		new("Frame", {
			Size = UDim2.new(1, -24, 0, 70),
			Position = UDim2.fromOffset(12, 12),
			BackgroundColor3 = m.color,
			BorderSizePixel = 0,
			Parent = card,
		}, { Theme.corner(12), Theme.stroke(2) })
		Theme.text({
			Text = m.name,
			Font = Theme.Display,
			Size = UDim2.new(1, -24, 0, 28),
			Position = UDim2.fromOffset(12, 90),
			Parent = card,
		})
		Theme.text({
			Text = `{m.role} · {m.rarity}`,
			TextColor3 = C.teal,
			Size = UDim2.new(1, -24, 0, 20),
			Position = UDim2.fromOffset(12, 120),
			Parent = card,
		})
		local statText = {}
		for code, v in m.stats do
			table.insert(statText, `{Progression.StatByCode[code].name} +{v}`)
		end
		table.sort(statText)
		Theme.text({
			Text = table.concat(statText, "\n") .. "\n" .. m.passive,
			TextColor3 = C.muted,
			TextSize = 14,
			TextScaled = false,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -24, 0, 90),
			Position = UDim2.fromOffset(12, 144),
			Parent = card,
		})
		local pick = Theme.button({
			Text = "Pick",
			Size = UDim2.new(1, -24, 0, 36),
			Position = UDim2.new(0, 12, 1, -46),
			Parent = card,
		})
		pick.Activated:Connect(function()
			Net.send("ChooseMutation", id)
			close()
		end)
	end
end

function PanelController:init()
	gui = new("ScreenGui", {
		Name = "Panels",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Net.listen("PantryOpen", picker)
	Net.listen("ChooseMutation", chooseMutation)
	HudController:menuButton("Stats").Activated:Connect(function()
		stats(false)
	end)
	HudController:menuButton("Menu").Activated:Connect(function()
		menu(nil)
	end)
	HudController:menuButton("Upgrade").Activated:Connect(upgrade)
	Store.Changed:Connect(function(partial)
		if open and open.kind == "Stats" and (partial.statPoints ~= nil or partial.effective) and open.refresh then
			open.refresh()
		end
	end)
end

function PanelController:isOpen()
	return open ~= nil
end

return PanelController

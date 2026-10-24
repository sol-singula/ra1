--[[
The Collection Log: 27 cards (every seed in Wet, Golden and Wet + Golden) and the milestone bar (5, 10, 18, 27).
A found entry shows how many times; an unclaimed one has Claim (its first-find coins). A milestone with enough
entries found has Claim too.

  CollectionController.open() / close() / isOpen() / fill()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local CollectionController = {}

local MUTS = { { "wet", "Wet" }, { "golden", "Golden" }, { "wetgolden", "Wet + Golden" } }
local MILESTONE_TEXT = {
	tag_collector = "Collector tag",
	deco_lantern = "Lantern",
	pedestal_plus1 = "+1 pedestal",
	title_master = "Master title",
}

local modal

local function milestones()
	local out = {}
	for n, reward in Config.Collection.milestones do
		table.insert(out, { n = n, reward = reward })
	end
	table.sort(out, function(a, b)
		return a.n < b.n
	end)
	return out
end

local function card(grid, i, seed, mut, c)
	local entry = seed .. ":" .. mut[1]
	local found = c.found[entry]
	local f = UI.frame(grid, {
		Name = "Card_" .. seed .. "_" .. mut[1],
		LayoutOrder = i,
		BackgroundColor3 = if found then UI.COLORS.card else UI.COLORS.grey,
	})
	local name = if found then `{mut[2]} {Config.Seeds[seed].name}` else "???"
	UI.label(f, name, { Name = "Name", Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 2) })
	local info = if found then `found x{found.n}` else `{UI.money(Config.Collection.firstFind[mut[1]])} coins`
	UI.label(f, info, { Name = "Info", Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 34) })
	if found and not c.claimed[entry] then
		UI.button(f, "Claim", function()
			Net.request("Collection", "claim", { entry = entry })
		end, { Name = "Claim", Size = UDim2.new(1, -8, 0, UI.MIN_TAP), Position = UDim2.fromOffset(4, 62) })
	end
end

function CollectionController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		return
	end
	local c = p.collection
	local total = #Config.Restock.order * #MUTS
	local found = 0
	for _ in c.found do
		found += 1
	end
	local bar = UI.frame(modal.body, { Name = "Milestones", Size = UDim2.new(1, 0, 0, 102), LayoutOrder = 1 })
	UI.label(
		bar,
		`{found}/{total} found`,
		{ Name = "Count", Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 4) }
	)
	local track = UI.frame(bar, {
		Name = "Track",
		Position = UDim2.fromOffset(8, 32),
		Size = UDim2.new(1, -16, 0, 10),
		BackgroundColor3 = UI.COLORS.grey,
	})
	UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(found / total, 1), BackgroundColor3 = UI.COLORS.green })
	for i, m in milestones() do
		local key = tostring(m.n)
		local x = (i - 1) / 4
		local done = c.milestones[key] == true
		local text = `{m.n}: {MILESTONE_TEXT[m.reward] or m.reward}`
		local props = {
			Name = "Milestone_" .. m.n,
			Position = UDim2.new(x, 8, 0, 46),
			Size = UDim2.new(0.25, -12, 0, UI.MIN_TAP),
		}
		if not done and found >= m.n then
			UI.button(bar, "Claim " .. text, function()
				Net.request("Collection", "claim", { milestone = m.n })
			end, props)
		else
			props.TextColor3 = if done then UI.COLORS.green else UI.COLORS.ink
			UI.label(bar, (if done then "✓ " else "") .. text, props)
		end
	end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 2
	grid.Size = UDim2.new(1, 0, 1, -110)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = modal.body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(140, 114)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local i = 0
	for _, seed in Config.Restock.order do
		for _, mut in MUTS do
			i += 1
			card(grid, i, seed, mut, c)
		end
	end
end

function CollectionController.open()
	CollectionController.fill()
	modal.open()
end

function CollectionController.close()
	modal.close()
end

function CollectionController.isOpen()
	return modal.isOpen()
end

function CollectionController:Start()
	modal = UI.modal("Collection", "Collection Log")
	modal.card.Size = UDim2.fromOffset(500, 620)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.collection) then
			CollectionController.fill()
		end
	end)
end

return CollectionController

--[[
Guidance on screen (master plan §16): one primary task on a card low in the middle, with a BUY button when it's
an affordable upgrade; an arrow in the world over its target (a tile, the stand, the preview); the secondary
goals as small lines at the right; the milestone (the next building and its price) under them. A done task flashes
"DONE" and the next one pops in.

  TaskController.refs    card, text, buy, goals, milestone, arrow (tests)
  TaskController.state() the last Net "Task"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TaskController = { Name = "TaskController", Order = 30 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = { goals = {} }
TaskController.refs = refs
local state = {}
local lastKey
local target -- a world Vector3 the arrow points at, or nil

function TaskController.state()
	return state
end

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

-- Where the task is in the world
local function targetOf(primary)
	local i = territoryIndex()
	if not i or not primary then
		return nil
	end
	local crops = Store.get("crops")
	if primary.kind == "tile" then
		-- the first empty tile (to plant) or the first ripe one (to harvest), else the first tile
		local want = primary.key == "harvest1" and "planted" or "empty"
		local first
		for _, key in Layout.FIELD_LIST do
			for n = 1, Layout.FIELDS[key].tiles do
				local id = Layout.tileId(key, n)
				local t = crops and crops.tiles[id]
				if t ~= nil then
					first = first or id
					if (want == "empty" and t == false) or (want == "planted" and t) then
						local x, z = Layout.tilePos(key, n)
						return Layout.toWorld(i, x, z, 1)
					end
				end
			end
		end
		if first then
			local key, n = Layout.parseTile(first)
			local x, z = Layout.tilePos(key, n)
			return Layout.toWorld(i, x, z, 1)
		end
	elseif primary.kind == "stand" then
		return Layout.toWorld(i, Layout.SPOTS.stand.x, Layout.SPOTS.stand.z - 6, 1)
	elseif primary.kind == "upgrade" then
		-- a building: its preview post; a field: its sign; else the UPGRADES button (no world target)
		local key = primary.target
		local model = workspace:FindFirstChild("Territories") and workspace.Territories:FindFirstChild("T" .. i)
		if model then
			local pv = model:FindFirstChild("Preview")
			local ghost = pv and pv:FindFirstChild("Ghost")
			if ghost and ghost:GetAttribute("Upgrade") == key then
				local post = pv:FindFirstChild("PreviewSign")
				return post and post.Position + Vector3.new(0, 3, 0) or nil
			end
			local fields = model:FindFirstChild("Fields")
			if fields then
				for _, d in fields:GetChildren() do
					if d.Name == "ZoneSign" and d:GetAttribute("Field") == key then
						return d.Position + Vector3.new(0, 2, 0)
					end
				end
			end
		end
	end
	return nil
end

local function paint()
	local t = Store.get("task")
	if not t then
		return
	end
	state = t
	local pr = t.primary
	if pr then
		refs.text.Text = pr.text or ""
		refs.badge.Text = t.onboarding and `STEP {pr.step or 1}/{pr.of or 1}` or "NEXT"
		refs.badge.BackgroundColor3 = t.onboarding and C.mustard or Constants.PALETTE.accent
		local showBuy = pr.kind == "upgrade" and pr.target ~= nil
		refs.buy.Visible = showBuy
		if showBuy then
			refs.buy.Text = pr.affordable and `BUY {Format.cash(pr.cost or 0)}` or `NEED {Format.cash(pr.cost or 0)}`
			refs.buy.BackgroundColor3 = pr.affordable and C.good or C.grey
		end
		if pr.key ~= lastKey then
			if lastKey then
				refs.done.Visible = true
				task.delay(1.4, function()
					refs.done.Visible = false
				end)
			end
			lastKey = pr.key
			Theme.pop(refs.card)
		end
		refs.card.Visible = true
		Bus.Highlight:Fire(pr.kind == "upgrade" and targetOf(pr) == nil and "upgrades" or nil)
	else
		refs.card.Visible = false
	end
	for k = 1, 3 do
		local g = t.goals and t.goals[k]
		local line = refs.goals[k]
		line.Visible = g ~= nil
		if g then
			line.Text = `☐ {g.text}  {g.have}/{g.n}  (+{Format.cash(g.reward)})`
		end
	end
	local m = t.milestone
	refs.milestone.Visible = m ~= nil
	if m then
		refs.milestone.Text = `🏗 NEXT: {m.name} · {Format.cash(m.cost)}\n{m.text or ""}`
	end
	target = targetOf(pr)
end

function TaskController:init()
	local gui = Theme.screen("Task", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(560, 76),
		Visible = false,
		Parent = gui,
	})
	refs.card = card
	refs.badge = Theme.title({
		Name = "Badge",
		Text = "STEP 1",
		Position = UDim2.fromOffset(-14, -18),
		Size = UDim2.fromOffset(110, 32),
		BackgroundColor3 = C.mustard,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		fit = 18,
		Parent = card,
	})
	refs.badge.BackgroundTransparency = 0
	Theme.corner(10).Parent = refs.badge
	Theme.stroke(3).Parent = refs.badge
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -190, 1, -22),
		Font = Theme.Display,
		fit = 22,
		Parent = card,
	})
	refs.buy = Theme.button({
		Name = "Buy",
		Text = "BUY",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = C.good,
		Visible = false,
		Parent = card,
	})
	refs.buy.Activated:Connect(function()
		local pr = state.primary
		if pr and pr.target then
			Net.send("Buy", pr.target)
		end
	end)
	refs.done = Theme.title({
		Name = "Done",
		Text = "DONE!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(200, 40),
		TextColor3 = C.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		fit = 30,
		Visible = false,
		Parent = card,
	})
	Theme.compact(card, 0.8)
	-- goals and the milestone at the right
	local col = Theme.new("Frame", {
		Name = "Goals",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -100, 0, 14),
		Size = UDim2.fromOffset(300, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.col = col
	for k = 1, 3 do
		refs.goals[k] = Theme.text({
			Name = "Goal" .. k,
			Text = "",
			Position = UDim2.fromOffset(0, (k - 1) * 26),
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.white,
			outline = 2,
			fit = 16,
			Visible = false,
			Parent = col,
		})
	end
	refs.milestone = Theme.text({
		Name = "Milestone",
		Text = "",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Constants.PALETTE.preview,
		outline = 2,
		fit = 16,
		Visible = false,
		Parent = col,
	})
	Theme.compact(col, 0.8)
	-- the arrow in the world
	local arrow = Shapes.wedge(
		workspace,
		Vector3.new(2.4, 2, 2.4),
		CFrame.new(0, -50, 0),
		Constants.PALETTE.accent,
		{ CanQuery = false }
	)
	arrow.Name = "TaskArrow"
	arrow.CastShadow = false
	arrow.Transparency = 1
	refs.arrow = arrow

	paint()
	Store.Changed:Connect(function(partial)
		if partial.task or partial.crops or partial.territory then
			paint()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if target then
			local t = os.clock()
			arrow.Transparency = 0
			arrow.CFrame = CFrame.new(target + Vector3.new(0, 4 + math.sin(t * 4) * 0.5, 0))
				* CFrame.Angles(math.pi, t * 1.5, 0)
		else
			arrow.Transparency = 1
		end
	end)
end

return TaskController

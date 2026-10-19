--[[
The guide (master plan §16): one task at a time, always pointed at.

  In the world   a big bouncing gold chevron over the target with a word under it ("STEP HERE", "TAP TO PLANT",
                 "HARVEST", "YOUR STAND"), a pulsing ring on the ground round it, and a trail of glowing dots from
                 your feet to it when it's more than a few steps away. Upgrade steps point at their build pad.
  On screen      the step card low in the middle: a numbered badge, "STEP 2 OF 9", the words, the reward chip,
                 a BUY / NEED button for an upgrade, the tutorial's progress bar, "DONE! +$25" when a step ends.
                 The goals card at the left (three goals with bars and rewards, then the next building and how
                 close you are to it). A welcome card after the opening flight.

  TaskController.refs    card, text, kicker, reward, buy, bar, goals, goalBars, milestone, arrow, ring (tests)
  TaskController.state() the last Net "Task"
  TaskController.target() the world point the arrow is on, or nil
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TaskController = { Name = "TaskController", Order = 30 }

local C = Theme.Color
local rgb = Color3.fromRGB
local GOLD = rgb(255, 205, 50)
local CASH = rgb(120, 230, 110)
local DOTS = 18
local player = Players.LocalPlayer
local refs = { goals = {}, goalBars = {}, goalRewards = {}, dots = {} }
TaskController.refs = refs
local state = {}
local lastKey
local target, targetWord -- the world point the arrow is on, and the word under it
local welcomed = false

function TaskController.state()
	return state
end

function TaskController.target()
	return target
end

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

local function territoryModel(i)
	local root = workspace:FindFirstChild("Territories")
	return root and root:FindFirstChild("T" .. i)
end

-- The first tile in the state wanted (false = empty, true = planted), else the first tile
local function tileTarget(i, wantPlanted)
	local crops = Store.get("crops")
	local first
	for _, key in Layout.FIELD_LIST do
		for n = 1, Layout.FIELDS[key].tiles do
			local id = Layout.tileId(key, n)
			local t = crops and crops.tiles[id]
			if t ~= nil then
				first = first or id
				if (wantPlanted and t) or (not wantPlanted and t == false) then
					local x, z = Layout.tilePos(key, n)
					return Layout.toWorld(i, x, z, 0.6)
				end
			end
		end
	end
	if first then
		local key, n = Layout.parseTile(first)
		local x, z = Layout.tilePos(key, n)
		return Layout.toWorld(i, x, z, 0.6)
	end
	return nil
end

-- Where the task is in the world, and the word to show there
local function targetOf(primary)
	local i = territoryIndex()
	if not i or not primary then
		return nil
	end
	if primary.kind == "tile" then
		local harvest = primary.key == "harvest1"
		return tileTarget(i, harvest), harvest and "HARVEST" or "TAP TO PLANT"
	elseif primary.kind == "plantAll" then
		return tileTarget(i, false), "PLANT ALL"
	elseif primary.kind == "stand" then
		return Layout.toWorld(i, Layout.SPOTS.stand.x, Layout.SPOTS.stand.z - 6, 0.2), "YOUR STAND"
	elseif primary.kind == "upgrade" then
		local key = primary.target
		local model = territoryModel(i)
		if model then
			-- its build pad first (step on it to buy)
			local pads = model:FindFirstChild("Pads")
			if pads then
				for _, m in pads:GetChildren() do
					if m:GetAttribute("Upgrade") == key then
						local top = m:FindFirstChild("Pad")
						if top then
							return top.Position, primary.affordable and "STEP HERE" or "SAVE UP"
						end
					end
				end
			end
			local pv = model:FindFirstChild("Preview")
			local ghost = pv and pv:FindFirstChild("Ghost")
			if ghost and ghost:GetAttribute("Upgrade") == key then
				local post = pv:FindFirstChild("PreviewSign", true)
				local part = post and (post:IsA("BasePart") and post or post:FindFirstChildWhichIsA("BasePart", true))
				if part then
					return part.Position, "BUILD HERE"
				end
			end
		end
	end
	return nil
end

local function paintGoals(t)
	local p = Store.get("profile")
	for k = 1, 3 do
		local g = t.goals and t.goals[k]
		local row = refs.goalRows[k]
		row.Visible = g ~= nil
		if g then
			refs.goals[k].Text = g.text
			refs.goalRewards[k].Text = `+{Format.cash(g.reward)}`
			local f = g.n > 0 and math.clamp(g.have / g.n, 0, 1) or 0
			refs.goalBars[k].Size = UDim2.fromScale(math.max(f, 0.04), 1)
			refs.goalCounts[k].Text = `{Format.num(g.have)} / {Format.num(g.n)}`
		end
	end
	local m = t.milestone
	refs.mile.Visible = m ~= nil
	if m then
		refs.milestone.Text = `NEXT: {m.name}`
		refs.mileCost.Text = Format.cash(m.cost)
		local cash = p and p.cash or 0
		local f = (m.cost or 0) > 0 and math.clamp(cash / m.cost, 0, 1) or 0
		refs.mileBar.Size = UDim2.fromScale(math.max(f, 0.03), 1)
	end
end

local function paint()
	local t = Store.get("task")
	if not t then
		return
	end
	state = t
	local pr = t.primary
	if pr and pr.kind ~= "none" then
		refs.text.Text = pr.text or ""
		if t.onboarding and pr.step then
			refs.kicker.Text = `STEP {pr.step} OF {pr.of or pr.step}`
			refs.num.Text = tostring(pr.step)
			refs.bar.Size = UDim2.fromScale(math.max((pr.step - 1) / math.max(pr.of or 1, 1), 0.03), 1)
			refs.barFrame.Visible = true
		else
			refs.kicker.Text = "NEXT UPGRADE"
			refs.num.Text = "★"
			refs.barFrame.Visible = false
		end
		refs.reward.Visible = (pr.reward or 0) > 0
		refs.reward.Text = `+{Format.cash(pr.reward or 0)}`
		local showBuy = pr.kind == "upgrade" and pr.target ~= nil
		refs.buy.Visible = showBuy
		if showBuy then
			refs.buy.Text = pr.affordable and `BUY {Format.cash(pr.cost or 0)}` or `NEED {Format.cash(pr.cost or 0)}`
			refs.buy.BackgroundColor3 = pr.affordable and C.good or rgb(84, 70, 60)
		end
		refs.text.Size = UDim2.new(1, showBuy and -250 or -96, 0, 46)
		if pr.key ~= lastKey then
			if lastKey then
				refs.done.Text = refs.lastReward and `DONE! +{Format.cash(refs.lastReward)}` or "DONE!"
				refs.done.Visible = true
				Theme.pop(refs.done)
				task.delay(1.6, function()
					refs.done.Visible = false
				end)
			end
			lastKey = pr.key
			refs.lastReward = pr.reward
			Theme.pop(refs.card)
		end
		refs.card.Visible = true
	else
		refs.card.Visible = false
	end
	paintGoals(t)
	target, targetWord = targetOf(pr)
	local hl = nil
	if pr and pr.kind == "upgrade" and target == nil then
		hl = "upgrades"
	elseif pr and pr.kind == "plantAll" then
		hl = "plantAll"
	end
	Bus.Highlight:Fire(hl)
end

-- A chevron: two bars in a V, drawn with frames (glyphs don't draw the same everywhere)
local function chevron(parent, y, color)
	local holder = Theme.new("Frame", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(80, 50),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		Theme.new("Frame", {
			Name = side < 0 and "L" or "R",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 17, 0.5, 0),
			Size = UDim2.fromOffset(50, 18),
			Rotation = side * 38,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		}, { Theme.corner(7), Theme.stroke(3, C.ink) })
	end
	return holder
end

local function buildWorld()
	local folder = Shapes.folder(workspace, "TaskGuide")
	refs.folder = folder
	local anchor = Shapes.part(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, -50, 0), GOLD, { CanQuery = false })
	anchor.Name = "TaskAnchor"
	anchor.Transparency = 1
	refs.anchor = anchor
	local bb = Instance.new("BillboardGui")
	bb.Name = "TaskArrow"
	bb.Size = UDim2.fromOffset(150, 170)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.Enabled = false
	refs.bob = Theme.new("Frame", {
		Name = "Bob",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = bb,
	})
	refs.word = Theme.title({
		Name = "Word",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(150, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		outline = 3,
		fit = 26,
		Parent = refs.bob,
	})
	chevron(refs.bob, 72, GOLD)
	chevron(refs.bob, 112, rgb(255, 160, 40))
	bb.Parent = anchor
	refs.arrow = bb
	-- the ring on the ground round the target
	local ring = Shapes.cylinder(
		folder,
		Vector3.new(0.15, 7, 7),
		CFrame.new(0, -50, 0) * CFrame.Angles(0, 0, math.pi / 2),
		GOLD,
		{ CanQuery = false }
	)
	ring.Name = "TaskRing"
	ring.Material = Enum.Material.Neon
	ring.CastShadow = false
	ring.Transparency = 1
	refs.ring = ring
	-- the trail
	for k = 1, DOTS do
		local d = Shapes.sphere(folder, Vector3.new(0.7, 0.25, 0.7), CFrame.new(0, -50, 0), GOLD, { CanQuery = false })
		d.Name = "TaskDot"
		d.Material = Enum.Material.Neon
		d.CastShadow = false
		d.Transparency = 1
		refs.dots[k] = d
	end
end

local function buildCard(gui)
	local card = Theme.slab({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92), -- (above the crop bar)
		Size = UDim2.fromOffset(620, 96),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	})
	refs.card = card
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = GOLD
		stroke.Thickness = 3
	end
	-- the round number badge
	local badge = Theme.new("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner("round"), Theme.stroke(3, C.ink) })
	refs.badge = badge
	refs.num = Theme.title({
		Name = "Num",
		Text = "1",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		fit = 34,
		Parent = badge,
	})
	refs.kicker = Theme.text({
		Name = "Kicker",
		Text = "STEP 1 OF 9",
		Position = UDim2.fromOffset(86, 10),
		Size = UDim2.fromOffset(240, 20),
		Font = Theme.Display,
		TextColor3 = GOLD,
		fit = 16,
		Parent = card,
	})
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(86, 30),
		Size = UDim2.new(1, -250, 0, 46),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 21,
		Parent = card,
	})
	refs.reward = Theme.text({
		Name = "Reward",
		Text = "+$10",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, -16),
		Size = UDim2.fromOffset(96, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = rgb(46, 150, 70),
		Font = Theme.Display,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 18,
		Visible = false,
		Parent = card,
	})
	refs.reward.BackgroundTransparency = 0
	Theme.corner("round").Parent = refs.reward
	Theme.stroke(3, C.ink).Parent = refs.reward
	refs.buy = Theme.button({
		Name = "Buy",
		Text = "BUY",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 2),
		Size = UDim2.fromOffset(150, 52),
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
	local barFrame, fill = Theme.bar({
		Name = "Progress",
		Position = UDim2.new(0, 86, 1, -16),
		Size = UDim2.new(1, -250, 0, 8),
	}, GOLD)
	barFrame.Parent = card
	refs.barFrame, refs.bar = barFrame, fill
	refs.done = Theme.title({
		Name = "Done",
		Text = "DONE!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(320, 46),
		TextColor3 = CASH,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		fit = 36,
		Visible = false,
		Parent = card,
	})
	Theme.compact(card, 0.78)
end

local function buildGoals(gui)
	local col = Theme.slab({
		Name = "Goals",
		Position = UDim2.fromOffset(16, 100),
		Size = UDim2.fromOffset(300, 214),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	refs.col = col
	Theme.text({
		Name = "Header",
		Text = "🎯 GOALS",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Theme.Display,
		TextColor3 = GOLD,
		fit = 18,
		Parent = col,
	})
	refs.goalRows, refs.goalCounts = {}, {}
	for k = 1, 3 do
		local row = Theme.new("Frame", {
			Name = "Goal" .. k,
			Position = UDim2.fromOffset(12, 32 + (k - 1) * 46),
			Size = UDim2.new(1, -24, 0, 42),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = col,
		})
		refs.goalRows[k] = row
		refs.goals[k] = Theme.text({
			Name = "Text",
			Text = "",
			Size = UDim2.new(1, -70, 0, 20),
			TextColor3 = C.white,
			fit = 16,
			Parent = row,
		})
		refs.goalRewards[k] = Theme.text({
			Name = "Reward",
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(68, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Display,
			TextColor3 = CASH,
			fit = 16,
			Parent = row,
		})
		local frame, fill = Theme.bar({
			Name = "Bar",
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -70, 0, 12),
		}, rgb(80, 200, 255))
		frame.Parent = row
		refs.goalBars[k] = fill
		refs.goalCounts[k] = Theme.text({
			Name = "Count",
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 22),
			Size = UDim2.fromOffset(68, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = rgb(220, 210, 196),
			fit = 13,
			Parent = row,
		})
	end
	-- the next building
	local mile = Theme.new("Frame", {
		Name = "Milestone",
		Position = UDim2.new(0, 12, 1, -42),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundTransparency = 1,
		Parent = col,
	})
	refs.mile = mile
	refs.milestone = Theme.text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -80, 0, 18),
		Font = Theme.Display,
		TextColor3 = rgb(140, 210, 255),
		fit = 15,
		Parent = mile,
	})
	refs.mileCost = Theme.text({
		Name = "Cost",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(80, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 15,
		Parent = mile,
	})
	local frame, fill = Theme.bar({
		Name = "Bar",
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 10),
	}, GOLD)
	frame.Parent = mile
	refs.mileBar = fill
	Theme.compact(col, 0.75)
end

local function buildWelcome(gui)
	local w = Theme.slab({
		Name = "Welcome",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(460, 210),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	})
	refs.welcome = w
	Theme.title({
		Name = "Title",
		Text = "WELCOME, FARMER!",
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		fit = 34,
		Parent = w,
	})
	Theme.text({
		Name = "Body",
		Text = "Grow crops, sell them at your stand, and step on the glowing build pads to grow your farm into an empire. Follow the gold arrow!",
		Position = UDim2.fromOffset(24, 62),
		Size = UDim2.new(1, -48, 0, 74),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		fit = 19,
		Parent = w,
	})
	local go = Theme.button({
		Name = "Go",
		Text = "LET'S GROW!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(220, 52),
		BackgroundColor3 = C.good,
		Parent = w,
	})
	refs.welcomeGo = go
	go.Activated:Connect(function()
		w.Visible = false
	end)
	Theme.compact(w, 0.8)
end

local function showWelcome()
	if welcomed then
		return
	end
	welcomed = true
	task.delay(3.8, function()
		local t = Store.get("task")
		if t and t.onboarding and t.primary and t.primary.step == 1 then
			refs.welcome.Visible = true
			Theme.pop(refs.welcome)
			task.delay(12, function()
				refs.welcome.Visible = false
			end)
		end
	end)
end

local function root()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function animate()
	local t = os.clock()
	if not target then
		refs.arrow.Enabled = false
		refs.ring.Transparency = 1
		for _, d in refs.dots do
			d.Transparency = 1
		end
		return
	end
	refs.anchor.CFrame = CFrame.new(target)
	refs.arrow.Enabled = true
	refs.word.Text = targetWord or ""
	refs.bob.Position = UDim2.fromOffset(0, math.sin(t * 5) * 10)
	local pulse = (t * 0.8) % 1
	local size = 6 + pulse * 3
	refs.ring.Size = Vector3.new(0.15, size, size)
	refs.ring.CFrame = CFrame.new(target + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	refs.ring.Transparency = 0.25 + pulse * 0.7
	-- the trail from the player's feet
	local hrp = root()
	local from = hrp and hrp.Position
	local far = from and Vector3.new(target.X - from.X, 0, target.Z - from.Z).Magnitude or 0
	local y = target.Y + 0.25
	for k, d in refs.dots do
		if from and far > 14 then
			local f = ((k - 1) / DOTS + t * 0.35) % 1
			local p = from:Lerp(target, f * 0.92 + 0.04)
			d.CFrame = CFrame.new(p.X, y, p.Z)
			d.Transparency = 0.15 + 0.6 * math.abs(f - 0.5)
		else
			d.Transparency = 1
		end
	end
end

function TaskController:init()
	local gui = Theme.screen("Task", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildCard(gui)
	buildGoals(gui)
	buildWelcome(gui)
	buildWorld()

	paint()
	Store.Changed:Connect(function(partial)
		if partial.task or partial.crops or partial.territory or partial.profile then
			paint()
		end
	end)
	Net.listen("Camera", function(c)
		if type(c) == "table" and c.kind == "opening" then
			showWelcome()
		end
	end)
	-- the pads are rebuilt by the server: look for the target again now and then
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= 0.5 then
			since = 0
			local pr = state.primary
			if pr and pr.kind == "upgrade" then
				target, targetWord = targetOf(pr)
			end
		end
		animate()
	end)
end

return TaskController

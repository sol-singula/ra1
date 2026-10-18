--[[
The animals on screen and in the world (master plan §6). Standing at a pen's pad opens its panel: the animal, its
level, its boost to the farm, fed or hungry (and for how long), what's waiting, FEED and UPGRADE (with the price)
(Net "Animal"). In the world, every animal on the street wanders its pen (this client moves them: the server only
places them), and the windmill turns.

  AnimalController.state()   the last Net "Animal"
  AnimalController.refs      the panel's pieces (tests)
  AnimalController.walkers() how many animals are being walked
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local AnimalController = { Name = "AnimalController", Order = 40, SPEED = 3 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
AnimalController.refs = refs
local state = { pens = {} }
local walking = {} -- [model] = { goal, pause }
local hubs = {} -- the windmills' hubs
local herds, lastScan = {}, -math.huge -- the animal models on the street, looked for every SCAN seconds
AnimalController.SCAN = 2

-- (the world is looked through now and then, never every frame: a phone has a thousand parts to skip)
local function scan()
	local folder = workspace:FindFirstChild("Farms")
	table.clear(herds)
	table.clear(hubs)
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d.Name == "Animal" and d:IsA("Model") then
			table.insert(herds, d)
		elseif d.Name == "WindmillHub" then
			table.insert(hubs, d)
		end
	end
end

function AnimalController.state()
	return state
end

function AnimalController.walkers()
	local n = 0
	for _ in walking do
		n += 1
	end
	return n
end

local function paint()
	local key = state.at
	local pen = key and state.pens and state.pens[key]
	refs.panel.Visible = pen ~= nil
	if not pen then
		return
	end
	local a = Animals[key]
	refs.title.Text = `{string.upper(a.name)}S · LEVEL {pen.level}`
	refs.boost.Text = "Boost: " .. (pen.boost or "")
	if pen.fed then
		refs.fed.Text = `Fed · {Format.time(pen.fedLeft or 0)} left`
		refs.fed.TextColor3 = C.good
	else
		refs.fed.Text = `Hungry! Feed {Animals.FEED_CROPS} crops for the full boost`
		refs.fed.TextColor3 = C.red
	end
	refs.ready.Text = pen.product and `{pen.product} waiting: {pen.ready or 0}` or ""
	refs.upgrade.Text = pen.maxed and "MAX LEVEL" or `UPGRADE {Format.cash(pen.cost or 0)}`
	refs.upgrade.Active = not pen.maxed
	refs.feed.Visible = not pen.fed
	local wait = pen.tendLeft or 0
	refs.tend.Visible = pen.product ~= nil
	refs.tend.Text = wait > 0 and `TEND {wait}s` or "TEND"
	refs.tend.BackgroundColor3 = wait > 0 and Color3.fromRGB(160, 160, 160) or Color3.fromRGB(245, 165, 40)
end

local function buildPanel(gui)
	local panel = Theme.card({
		Name = "Pen",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(330, 196),
		Visible = false,
		Parent = gui,
	})
	refs.panel = panel
	refs.title = Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 30),
		Font = Theme.Display,
		fit = 22,
		Parent = panel,
	})
	refs.boost = Theme.text({
		Name = "Boost",
		Text = "",
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 22),
		TextColor3 = Color3.fromRGB(40, 140, 70),
		fit = 16,
		Parent = panel,
	})
	refs.fed = Theme.text({
		Name = "Fed",
		Text = "",
		Position = UDim2.fromOffset(14, 64),
		Size = UDim2.new(1, -28, 0, 22),
		fit = 15,
		Parent = panel,
	})
	refs.ready = Theme.text({
		Name = "Ready",
		Text = "",
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 20),
		TextColor3 = C.muted,
		fit = 14,
		Parent = panel,
	})
	local feed = Theme.button({
		Name = "Feed",
		Text = "FEED",
		Position = UDim2.fromOffset(14, 128),
		Size = UDim2.fromOffset(88, 52),
		BackgroundColor3 = Color3.fromRGB(80, 190, 90),
		Parent = panel,
	})
	local tend = Theme.button({
		Name = "Tend",
		Text = "TEND",
		Position = UDim2.fromOffset(108, 128),
		Size = UDim2.fromOffset(96, 52),
		BackgroundColor3 = Color3.fromRGB(245, 165, 40),
		Parent = panel,
	})
	tend.Modal = true
	tend.Activated:Connect(function()
		if state.at then
			Net.send("Animal", "tend", state.at)
		end
	end)
	refs.tend = tend
	local up = Theme.button({
		Name = "Upgrade",
		Text = "UPGRADE",
		Position = UDim2.fromOffset(210, 128),
		Size = UDim2.new(1, -224, 0, 52),
		BackgroundColor3 = C.mustard,
		Parent = panel,
	})
	feed.Modal, up.Modal = true, true
	feed.Activated:Connect(function()
		if state.at then
			Net.send("Animal", "feed", state.at)
		end
	end)
	up.Activated:Connect(function()
		if state.at then
			Net.send("Animal", "upgrade", state.at)
		end
	end)
	refs.feed, refs.upgrade = feed, up
end

-- Wandering: each animal picks a spot in its pen, walks there, rests a moment, picks another
local function walk(dt)
	local seen = {}
	for _, d in herds do
		if d.Parent and d.PrimaryPart then
			seen[d] = true
			local w = walking[d]
			local mn, mx = d:GetAttribute("PenMin"), d:GetAttribute("PenMax")
			if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" then
				continue
			end
			if not w then
				w = { pause = math.random() * 2 }
				walking[d] = w
			end
			if w.pause > 0 then
				w.pause -= dt
				continue
			end
			local pos = d:GetPivot().Position
			if not w.goal then
				w.goal = Vector3.new(mn.X + math.random() * (mx.X - mn.X), pos.Y, mn.Z + math.random() * (mx.Z - mn.Z))
			end
			local to = Vector3.new(w.goal.X - pos.X, 0, w.goal.Z - pos.Z)
			local step = AnimalController.SPEED * dt
			if to.Magnitude <= step then
				w.goal = nil
				w.pause = 1 + math.random() * 3
			else
				local nextPos = pos + to.Unit * step
				d:PivotTo(CFrame.lookAt(nextPos, nextPos + to.Unit))
			end
		end
	end
	for m in walking do
		if not seen[m] then
			walking[m] = nil
		end
	end
end

local function spin(dt)
	for _, d in hubs do
		if d.Parent then
			local rate = d:GetAttribute("Spin") or 1
			local turn = CFrame.Angles(0, 0, rate * dt)
			local pivot = d.CFrame
			d.CFrame = pivot * turn
			for _, blade in d:GetChildren() do
				if blade:IsA("BasePart") then
					blade.CFrame = pivot * turn * pivot:ToObjectSpace(blade.CFrame)
				end
			end
		end
	end
end

function AnimalController:init()
	local gui = Theme.screen("Animals", 8, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildPanel(gui)
	Net.listen("Animal", function(m)
		if type(m) ~= "table" then
			return
		end
		state = m
		paint()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		if os.clock() - lastScan >= AnimalController.SCAN then
			lastScan = os.clock()
			scan()
		end
		walk(acc)
		spin(acc)
		acc = 0
	end)
end

return AnimalController

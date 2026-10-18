--[[
The guide on screen and in the world, ra9's way (master plan §9): one numbered step at a time, one big short
instruction, the exact spot lit up, the button it needs pulsing, a payoff when it's done.

  the step card   low in the middle: a gold STEP 3 badge, the instruction in big letters, CHAPTER 1 · THE SHACK and
                  how far through the chapter (a bar); GO when the spot is far (GuideService:Go puts you there, no
                  long walks); after the scripted steps a ★ NEXT GOAL, and a Special Order's ! in gold
  in the world    a light beam and a pulsing ring on the spot, a gold arrow bobbing over it, a dotted path on the
                  ground from you to it (gone once you're there)
  the button      Bus.Highlight: the farm's PLANT/HARVEST/WATER button pulses with a gold ring ("act"); a menu
                  button pulses through MenuController ("menu:<name>")
  the payoff      STEP 3 DONE! and its reward, big in the middle, then the next step pops in
  the tour        a brand-new farmer's first look (Net "Guide" fresh): letterbox, the camera over the farm, then
                  1 PLANT HERE (the soil), 2 SELL HERE (the stand), 3 BUY UPGRADES HERE (the pads); SKIP any time

  GuideController.state()   the last Net "Guide"
  GuideController.refs      the card, badge, GO, payoff, arrow, beam, ring, dots (tests)
  GuideController.touring() true while the tour plays
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)

local GuideController = { Name = "GuideController", Order = 30, DOTS = 24, SPACING = 3.5, HERE = 7, FAR = 30 }

local C = Theme.Color
local GOLD = Constants.PALETTE.sunflower
local GREEN = Color3.fromRGB(60, 185, 90)
local player = Players.LocalPlayer
local refs = { dots = {} }
GuideController.refs = refs
local state = {}
local tour -- the tour while it plays: { t0, shots, saved }
local toured = false

function GuideController.state()
	return state
end

function GuideController.touring()
	return tour ~= nil
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function worldPart(name, size, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Transparency = 1
	p.Parent = refs.folder
	return p
end

-- The card --------------------------------------------------------------------------------------------------------
local function far()
	local r = root()
	local t = state.target
	if not r or typeof(t) ~= "Vector3" then
		return false
	end
	return Vector3.new(r.Position.X - t.X, 0, r.Position.Z - t.Z).Magnitude >= GuideController.FAR
end

local function paintCard()
	refs.card.Visible = state.text ~= nil and tour == nil
	refs.text.Text = state.text or ""
	local special = type(state.key) == "string" and string.sub(state.key, 1, 8) == "special:"
	if special then
		refs.badgeTop.Text = "SPECIAL"
		refs.badgeNum.Text = "!"
		refs.chapter.Text = "SPECIAL ORDER: DROP EVERYTHING!"
		refs.badge.BackgroundColor3 = Color3.fromRGB(235, 90, 40)
	elseif state.generated or not state.n then
		refs.badgeTop.Text = "NEXT"
		refs.badgeNum.Text = "★"
		refs.chapter.Text = `NEXT GOAL · {state.percent or 100}% OF THE GAME DONE`
		refs.badge.BackgroundColor3 = GOLD
	else
		refs.badgeTop.Text = "STEP"
		refs.badgeNum.Text = tostring(state.n)
		refs.chapter.Text =
			`CHAPTER {state.chapter} · {state.chapterName or ""} · {state.n}/{state.chapterSize or state.n}`
		refs.badge.BackgroundColor3 = GOLD
	end
	-- (kept for the old tests and the HUD: how far through the whole game)
	refs.count.Text = state.percent and `{state.percent}%` or ""
	local k = state.n and state.chapterSize and (state.n - 1) / state.chapterSize or (state.percent or 0) / 100
	if type(state.goal) == "table" and (state.goal.need or 0) > 0 then
		-- (earning toward a buy: the bar is the Cash so far against the price)
		k = (state.goal.have or 0) / state.goal.need
		refs.chapter.Text = `${state.goal.have} / ${state.goal.need} for {state.goal.name}`
	end
	refs.fill.Size = UDim2.fromScale(math.clamp(k, 0.02, 1), 1)
end

local function payoff(old)
	if not old or not old.key or old.generated or not old.n then
		return
	end
	local r = old.reward or {}
	local bits = {}
	if r.cash then
		table.insert(bits, `+{r.cash} Cash`)
	end
	if r.xp then
		table.insert(bits, `+{r.xp} XP`)
	end
	refs.payTitle.Text = `✔ STEP {old.n} DONE!`
	refs.payLine.Text = table.concat(bits, "   ")
	refs.pay.Visible = true
	Theme.pop(refs.pay)
	local token = {}
	refs.payToken = token
	task.delay(1.6, function()
		if refs.payToken == token then
			refs.pay.Visible = false
		end
	end)
end

-- The tour ---------------------------------------------------------------------------------------------------------
local function endTour()
	if not tour then
		return
	end
	local cam = workspace.CurrentCamera
	pcall(function()
		cam.CameraType = Enum.CameraType.Custom
	end)
	refs.tour.Visible = false
	tour = nil
	paintCard()
end
GuideController.skipTour = endTour

local function startTour()
	local plot = player:GetAttribute("Plot")
	if toured or type(plot) ~= "number" then
		return
	end
	toured = true
	local S = PlotLayout.SPOTS
	local function w(v, y)
		return PlotLayout.toWorld(plot, v.X, v.Z, y or v.Y)
	end
	local soil, stand, pad = S.soil + Vector3.new(10, 0, 6), S.stand, S.pads[2]
	tour = {
		t0 = os.clock(),
		shots = {
			{
				eye = w(Vector3.new(30, 0, -175), 70),
				look = w(Vector3.new(-20, 0, -70), 0),
				text = "THIS IS YOUR FARM!",
				line = "It starts small. It gets HUGE.",
			},
			{
				eye = w(soil + Vector3.new(14, 0, -24), 15),
				look = w(soil, 0),
				text = "1  PLANT CROPS HERE",
				line = "Tap PLANT by the soil",
			},
			{
				eye = w(stand + Vector3.new(12, 0, -18), 11),
				look = w(stand, 2),
				text = "2  SELL THEM HERE",
				line = "Step on SELL at your stand",
			},
			{
				eye = w(pad + Vector3.new(4, 0, -20), 11),
				look = w(pad, 0),
				text = "3  BUY UPGRADES HERE",
				line = "Step on a pad to buy it",
			},
		},
	}
	refs.tour.Visible = true
	refs.card.Visible = false
	pcall(function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	end)
end

local SHOT = 2.2
local function tourStep()
	local t = os.clock() - tour.t0
	local i = math.floor(t / SHOT) + 1
	local shot = tour.shots[i]
	if not shot then
		endTour()
		return
	end
	local prev = tour.shots[math.max(1, i - 1)]
	local k = math.clamp((t - (i - 1) * SHOT) / 0.7, 0, 1)
	k = k * k * (3 - 2 * k)
	local eye = prev.eye:Lerp(shot.eye, k)
	local look = prev.look:Lerp(shot.look, k)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, look)
	refs.tourTitle.Text = shot.text
	refs.tourLine.Text = shot.line
end

-- The world --------------------------------------------------------------------------------------------------------
local function hideWorld()
	refs.arrow.Transparency = 1
	refs.tip.Transparency = 1
	refs.beam.Transparency = 1
	refs.ring.Transparency = 1
	for _, d in refs.dots do
		d.Transparency = 1
	end
end

local function step()
	if tour then
		tourStep()
	end
	local target = state.target
	local r = root()
	local t = os.clock()
	refs.go.Visible = state.text ~= nil and far()
	if typeof(target) ~= "Vector3" or not r then
		hideWorld()
		return
	end
	-- how far it is: up close only the ring stays (the beam and the arrow would just be in the way)
	local flat = Vector3.new(r.Position.X - target.X, 0, r.Position.Z - target.Z).Magnitude
	local near = math.clamp((flat - 10) / 20, 0, 1) -- 0 within 10 studs, 1 from 30
	-- the arrow: a gold block and a point under it, bobbing over the target (gone once you're there)
	local bob = math.sin(t * 3) * 0.5
	refs.arrow.CFrame = CFrame.new(target + Vector3.new(0, 6.5 + bob, 0)) * CFrame.Angles(0, t * 2, 0)
	refs.tip.CFrame = CFrame.new(target + Vector3.new(0, 4.9 + bob, 0)) * CFrame.Angles(0, t * 2, math.rad(45))
	local arrowT = flat < GuideController.HERE and 1 or 0.15
	refs.arrow.Transparency = arrowT
	refs.tip.Transparency = arrowT
	-- the spot: a thin, faint beam (far away only, to find it from across the farm) and a ring on the ground
	local ground = Vector3.new(target.X, target.Y + 0.25, target.Z) -- (just over a tile's or a pad's top)
	refs.beam.CFrame = CFrame.new(ground + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90))
	refs.beam.Transparency = 1 - near * (0.22 + 0.05 * math.sin(t * 4))
	local pulse = 1 + 0.1 * math.sin(t * 5)
	refs.ring.Size = Vector3.new(0.15, 6.5 * pulse, 6.5 * pulse)
	refs.ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	refs.ring.Transparency = 0.45
	-- the path: dots on the ground from here to there, moving toward it
	local from = Vector3.new(r.Position.X, target.Y, r.Position.Z)
	local to = target - from
	local dist = Vector3.new(to.X, 0, to.Z).Magnitude
	local here = dist < GuideController.HERE
	local dir = dist > 0 and Vector3.new(to.X, 0, to.Z).Unit or Vector3.zero
	local slide = (t * 4) % GuideController.SPACING
	for i, d in refs.dots do
		local along = (i - 1) * GuideController.SPACING + slide + 2
		if here or along > dist - 1.5 then
			d.Transparency = 1
		else
			d.CFrame = CFrame.new(from + dir * along + Vector3.new(0, 0.35, 0))
			d.Transparency = 0.25
		end
	end
end

function GuideController:init()
	local gui = Theme.screen("Guide", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	-- the step card, low in the middle
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(600, 92),
		BackgroundColor3 = C.paper,
		Visible = false,
		Parent = gui,
	})
	refs.card = card
	Theme.compact(card, 0.78)
	refs.badge = Theme.new("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(-14, -14),
		Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = GOLD,
		Parent = card,
	}, { Theme.corner("round"), Theme.stroke(4) })
	refs.badgeTop = Theme.title({
		Name = "Top",
		Text = "STEP",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = refs.badge,
	})
	refs.badgeNum = Theme.title({
		Name = "Num",
		Text = "1",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 52),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		Parent = refs.badge,
	})
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(100, 8),
		Size = UDim2.new(1, -210, 0, 50),
		Font = Theme.Display,
		fit = 30,
		Parent = card,
	})
	refs.chapter = Theme.text({
		Name = "Chapter",
		Text = "",
		Position = UDim2.fromOffset(100, 58),
		Size = UDim2.new(1, -210, 0, 16),
		TextColor3 = Color3.fromRGB(120, 110, 90),
		fit = 14,
		Parent = card,
	})
	local bar, fill = Theme.bar({
		Name = "Bar",
		Position = UDim2.fromOffset(100, 76),
		Size = UDim2.new(1, -210, 0, 8),
		Parent = card,
	}, GOLD)
	refs.bar, refs.fill = bar, fill
	refs.count = Theme.text({ -- (the old card's corner: the whole game's %)
		Name = "Count",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(96, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(150, 130, 90),
		fit = 13,
		Parent = card,
	})
	refs.go = Theme.button({
		Name = "Go",
		Text = "GO ▶",
		BackgroundColor3 = GREEN,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(96, 52),
		Visible = false,
		Parent = card,
	})
	refs.go.Activated:Connect(function()
		Bus.Tap:Fire("guide_go")
		Net.send("Guide", "go")
	end)
	-- the payoff, big in the middle
	refs.pay = Theme.new("Frame", {
		Name = "Payoff",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.compact(refs.pay, 0.7)
	refs.payTitle = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, 0, 0, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(120, 230, 110),
		outline = 4,
		Parent = refs.pay,
	})
	refs.payLine = Theme.title({
		Name = "Line",
		Text = "",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		outline = 3,
		Parent = refs.pay,
	})
	-- the tour: letterbox bars, a title and SKIP
	refs.tour = Theme.new("Frame", {
		Name = "Tour",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	for i, y in { 0, 1 } do
		Theme.new("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0.11, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = refs.tour,
		})
	end
	refs.tourTitle = Theme.title({
		Name = "Title",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromOffset(760, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		outline = 4,
		Parent = refs.tour,
	})
	refs.tourLine = Theme.title({
		Name = "Line",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.15, 74),
		Size = UDim2.fromOffset(700, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		Parent = refs.tour,
	})
	local skip = Theme.button({
		Name = "Skip",
		Text = "SKIP ▶",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 0.89, -10),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = Color3.fromRGB(90, 90, 100),
		Parent = refs.tour,
	})
	skip.Activated:Connect(endTour)
	refs.skip = skip
	-- the world's pieces
	local folder = Instance.new("Folder")
	folder.Name = "GuidePath"
	folder.Parent = workspace
	refs.folder = folder
	refs.arrow = worldPart("GuideArrow", Vector3.new(1.4, 2.4, 1.4))
	refs.tip = worldPart("GuideTip", Vector3.new(1.5, 1.5, 0.5))
	refs.beam = worldPart("GuideBeam", Vector3.new(28, 0.7, 0.7), Enum.PartType.Cylinder)
	refs.ring = worldPart("GuideRing", Vector3.new(0.2, 7.5, 7.5), Enum.PartType.Cylinder)
	for i = 1, GuideController.DOTS do
		refs.dots[i] = worldPart("GuideDot", Vector3.new(0.9, 0.12, 0.9))
	end
	Net.listen("Guide", function(g)
		if type(g) ~= "table" then
			return
		end
		local old = state
		state = g
		if old.key and old.key ~= g.key and old.step ~= g.step then
			payoff(old)
		end
		paintCard()
		Theme.pop(card)
		Bus.Highlight:Fire(g.button == "act" and "act" or nil)
		if g.fresh then
			startTour()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return GuideController

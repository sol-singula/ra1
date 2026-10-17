--[[
A shop card's picture brought to life (PanelController's cards and its BUY IT? dialog): the item itself, playing on a
loop, over or in place of its still picture (Icons.cosmetic):

  effect   a little stage in a ViewportFrame (a WorldModel, a floor, a blocky dummy): the dummy stands a beat, then
           the kill effect plays on it for real (FX/KillEffects, quiet and light), and again every few seconds. A
           viewport doesn't draw billboards, so the effect's words and stickers are drawn over the frame here, where
           the camera sees them; the lightning's dark sky darkens the frame
  skin     the bow turning round, its moving colours (rainbow, lava...) moving
  sword    the blade turning round, its moving colours moving, its lines throbbing (Flair.sword)
  trail    the arrow swishing through, its streak behind it
  banner   the flag waving, its emblem alive (Flair.banner)
  title    the nameplate bobbing

Light on phones: only a card that's on screen plays (its scroll areas and the panel's own Visible), at most MAX at once
(fewer on phones and low graphics: an effect counts 1, the cheap ones half), a dialog's preview first (the cards under
it wait); everything stops when the panel closes. A preview that can't be built leaves the still picture.

  ItemPreview.attach(box, item, opts?) -> slot   box: the picture's frame (its still Icon inside it)
        opts = { priority? (a dialog's: plays first, and alone), cover? { GuiObject } (hidden while it plays) }
  ItemPreview.stop()        every preview stopped and forgotten (the panel closing)
  ItemPreview.running()   ItemPreview.slots()   ItemPreview.load()   ItemPreview.broken()   ItemPreview.budget()
                            how many play, are attached, what they cost, couldn't be built, the cap   (tests)
  ItemPreview.step(dt)      one frame (RenderStepped calls it while any are attached)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Effects = require(script.Parent.Parent.FX.Effects)
local Flair = require(script.Parent.Parent.FX.Flair)
local KillEffects = require(script.Parent.Parent.FX.KillEffects)
local Store = require(script.Parent.Parent.Store)
local SwordSkins = require(ReplicatedStorage.Shared.SwordSkins)

local ItemPreview = {}

local BUDGET = { high = 6, mid = 6, low = 4 } -- (an effect costs 1, the cheap ones half)
local COST = { effect = 1, skin = 0.5, sword = 0.5, trail = 0.5, banner = 0.25, title = 0.25 }
local PICK_EVERY = 0.25 -- seconds between looks at what's on screen
local STAND = 0.5 -- the dummy stands this long before the effect plays
local PERIOD = 3.8 -- one loop of an effect (KillEffects' life is 2.8)
local WHITE = Color3.new(1, 1, 1)
local AMBIENT = Color3.fromRGB(175, 175, 182)
local NIGHT = Color3.fromRGB(80, 95, 140)
local UP = Vector3.yAxis
-- the stage: the dummy's middle at MID (feet on the floor at 0), the camera a little above and to the side
local MID = Vector3.new(0, 3, 0)
local FOV = 50
local CAM = CFrame.lookAt(Vector3.new(6, 7.5, 19), Vector3.new(0, 5.2, 0))

local slots = {} -- { box, it, opts, kind, live?, broken?, n }
local stepping
local pickIn = 0
local order = 0

local function budget()
	local ok, t = pcall(Effects.tier)
	return BUDGET[ok and t or "low"] or 4
end

local function otherTeam(team)
	return team == "blue" and "red" or "blue"
end

-- On screen: in a shown panel, every frame up to its screen Visible, and (with a layout) mostly inside every scroll
-- area or clipping frame it's in
local function onScreen(box)
	if not box.Parent or not box:IsDescendantOf(game) then
		return false
	end
	local x = box
	while x and not x:IsA("LayerCollector") do
		if x:IsA("GuiObject") and x.Visible == false then
			return false
		end
		x = x.Parent
	end
	if not x or (x:IsA("ScreenGui") and x.Enabled == false) then
		return false
	end
	local pos, size = box.AbsolutePosition, box.AbsoluteSize
	if typeof(pos) ~= "Vector2" or typeof(size) ~= "Vector2" then
		return true -- (no layout to ask: the mock engine)
	end
	if size.X < 4 or size.Y < 4 then
		return false
	end
	local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
	local p = box.Parent
	while p and p:IsA("GuiObject") do
		if p.ClipsDescendants or p:IsA("ScrollingFrame") then
			local pp, ps = p.AbsolutePosition, p.AbsoluteSize
			x0, y0 = math.max(x0, pp.X), math.max(y0, pp.Y)
			x1, y1 = math.min(x1, pp.X + ps.X), math.min(y1, pp.Y + ps.Y)
		end
		p = p.Parent
	end
	return math.max(0, x1 - x0) * math.max(0, y1 - y0) >= size.X * size.Y * 0.35
end

local function aspectOf(inst)
	local s = inst.AbsoluteSize
	if typeof(s) == "Vector2" and s.Y > 0 then
		return s.X / s.Y
	end
	local z = inst.Size
	return (z and z.Y.Offset > 0) and z.X.Offset / z.Y.Offset or 1.6
end

local function newInst(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- Kill effects: a stage in a viewport --------------------------------------------------------------------------
-- (a billboard's word or sticker, drawn where the camera sees its anchor, as big as it is in studs there)
local function mirror(live)
	local fx = live.fx
	local cam = live.cam
	local tanV = math.tan(math.rad(FOV / 2))
	local aspect = aspectOf(live.holder)
	local seen = {}
	for _, gui in fx and fx.boards or {} do
		local anchor = gui.Adornee
		local src = gui:FindFirstChildWhichIsA("GuiObject")
		if gui.Parent and anchor and anchor.Parent and src then
			seen[gui] = true
			local view = live.views[gui]
			if not view then
				view = newInst("Frame", {
					Name = "Board",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					ZIndex = 2,
				}, live.words)
				local copy
				if src:IsA("ImageLabel") then
					copy = newInst("ImageLabel", { ScaleType = Enum.ScaleType.Fit }, view)
				else
					copy = newInst("TextLabel", { TextScaled = true, Font = src.Font }, view)
				end
				copy.Name = src.Name
				copy.BackgroundTransparency = 1
				copy.AnchorPoint = Vector2.new(0.5, 0.5)
				copy.Position = UDim2.fromScale(0.5, 0.5)
				copy.Size = UDim2.fromScale(1, 1)
				copy.ZIndex = 2
				live.views[gui] = view
			end
			local q = cam.CFrame:PointToObjectSpace(anchor.Position)
			local depth = -q.Z
			view.Visible = depth > 0.5
			if depth > 0.5 then
				local k = depth * tanV * 2
				view.Position = UDim2.fromScale(0.5 + q.X / (k * aspect), 0.5 - q.Y / k)
				view.Size = UDim2.fromScale(gui.Size.X.Scale / (k * aspect), gui.Size.Y.Scale / k)
				local copy = view:FindFirstChild(src.Name)
				copy.Rotation = src.Rotation
				if src:IsA("ImageLabel") then
					copy.Image = src.Image
					copy.ImageTransparency = src.ImageTransparency
				else
					copy.Text = src.Text
					copy.TextColor3 = src.TextColor3
					copy.TextTransparency = src.TextTransparency
					copy.TextStrokeColor3 = src.TextStrokeColor3
					copy.TextStrokeTransparency = src.TextStrokeTransparency
				end
			end
		end
	end
	for gui, view in live.views do
		if not seen[gui] then
			view:Destroy()
			live.views[gui] = nil
		end
	end
	-- (the lightning: the sky goes dark, then the flash)
	local g = fx and fx.alive and fx.grade
	local b = g and g.Parent and g.Brightness or 0
	if b < 0 then
		local d = math.min(1, -b / 0.35)
		live.vf.ImageColor3 = WHITE:Lerp(NIGHT, d)
		live.vf.Ambient = AMBIENT
		live.holder.BackgroundTransparency = 1 - d * 0.55
	else
		live.vf.ImageColor3 = WHITE
		live.vf.Ambient = AMBIENT:Lerp(WHITE, math.min(1, b / 0.6))
		live.holder.BackgroundTransparency = 1
	end
end

local function dummyShown(live, on)
	if live.dummy then
		live.dummy.Parent = on and live.world or nil
	end
end

local function effectStart(slot)
	local holder = newInst("Frame", {
		Name = "Live",
		BackgroundColor3 = Color3.fromRGB(10, 12, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, nil)
	local vf = newInst("ViewportFrame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = AMBIENT,
		LightColor = WHITE,
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = 0,
	}, holder)
	local world = newInst("WorldModel", { Name = "World" }, vf)
	local cam = newInst("Camera", { FieldOfView = FOV, CFrame = CAM }, vf)
	vf.CurrentCamera = cam
	newInst("Part", {
		Name = "Floor",
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 10, 10),
		CFrame = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(214, 218, 228),
		Material = Enum.Material.SmoothPlastic,
	}, world)
	local words = newInst("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, holder)
	local team = Store.team() or "red"
	local dummy = Effects.mannequin(CFrame.new(MID), otherTeam(team))
	dummy.Name = "Dummy"
	dummy.Parent = world
	holder.Parent = slot.box
	return {
		holder = holder,
		vf = vf,
		world = world,
		cam = cam,
		words = words,
		dummy = dummy,
		team = team,
		views = {},
		t = 0,
	}
end

local function effectStep(slot, live, dt)
	live.t += dt
	if not live.fx and not live.played and live.t >= STAND then
		live.played = true
		dummyShown(live, false) -- (they're gone: the effect takes over)
		live.fx = KillEffects.play(slot.it.key, MID, live.team, {
			preview = true,
			parent = live.world,
			ground = Vector3.zero,
			victimTeam = otherTeam(live.team),
			dir = Vector3.new(1, 0, 0.3),
		})
		if not live.fx then
			error("no effect")
		end
	end
	if live.fx and not live.fx:step(dt) then
		live.fx = nil
	end
	if live.t >= PERIOD then
		-- again: the dummy back on its feet
		if live.fx then
			live.fx:destroy()
			live.fx = nil
		end
		live.t, live.played = 0, false
		dummyShown(live, true)
	end
	mirror(live)
end

local function effectStop(_, live)
	if live.fx then
		live.fx:destroy()
	end
	live.holder:Destroy()
	if live.dummy then
		live.dummy:Destroy()
	end
end

-- The cheap ones: the still picture itself moves ------------------------------------------------------------------
local function modelOf(icon)
	local model = icon and icon:IsA("ViewportFrame") and icon:FindFirstChildWhichIsA("Model")
	if not model then
		error("no model")
	end
	local rest, sum, n = {}, Vector3.zero, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			rest[p] = p.CFrame
			sum += p.Position
			n += 1
		end
	end
	return model, rest, n > 0 and sum / n or Vector3.zero
end

local function restore(live)
	for p, c in live.rest or {} do
		p.CFrame = c
	end
	for p, c in live.colors or {} do
		p.Color = c
	end
end

local function bowStart(slot)
	local _, rest, center = modelOf(slot.icon)
	local look = slot.it.look or {}
	local team = Store.team() or "red"
	-- (its moving colours: the parts in that colour now, by token)
	local colors, tokens = {}, {}
	for _, tk in { look.limbs, look.grip } do
		if tk and Flair.moving(tk) then
			local c = Cosmetics.color(tk, team)
			for p in rest do
				if p.Color == c and not tokens[p] then
					colors[p], tokens[p] = p.Color, tk
				end
			end
		end
	end
	return { rest = rest, center = CFrame.new(center), colors = colors, tokens = tokens, team = team, t = 0 }
end

local function bowStep(_, live, dt)
	live.t += dt
	local t = live.t
	local turn = live.center
		* CFrame.new(UP * math.sin(t * 2) * 0.06)
		* CFrame.Angles(0, t * 1.3, 0)
		* live.center:Inverse()
	for p, c in live.rest do
		p.CFrame = turn * c
	end
	for p, tk in live.tokens do
		p.Color = Flair.tint(tk, live.team, t, p.Position.Y * 0.1)
	end
end

-- the sword: turning like the bow, its colours and lines alive (Flair.sword on the picture's own parts)
local function swordStart(slot)
	local model, rest, center = modelOf(slot.icon)
	local look = slot.it.look or {}
	local team = Store.team() or "red"
	local colors = {}
	for p in rest do
		colors[p] = p.Color
	end
	local sword = SwordSkins.adopt(model, look, team)
	return {
		rest = rest,
		center = CFrame.new(center),
		colors = colors,
		flair = Flair.sword(sword, look, team),
		t = 0,
	}
end

local function swordStep(_, live, dt)
	live.t += dt
	local t = live.t
	local turn = live.center
		* CFrame.new(UP * math.sin(t * 2) * 0.06)
		* CFrame.Angles(0, t * 1.3, 0)
		* live.center:Inverse()
	for p, c in live.rest do
		p.CFrame = turn * c
	end
	live.flair:update(os.clock())
end

local function swordStop(_, live)
	live.flair:destroy()
	restore(live)
end

-- the arrow comes in from the left, hangs a moment, and is gone off the right
local function trailStep(_, live, dt)
	live.t = (live.t + dt) % 2.4
	local u = live.t
	local x
	if u < 0.45 then
		x = -14 * (1 - u / 0.45) ^ 3
	elseif u < 1.9 then
		x = (u - 0.45) * 0.4
	elseif u < 2.25 then
		x = 0.58 + 18 * ((u - 1.9) / 0.35) ^ 2
	else
		x = 40
	end
	local move = CFrame.new(x, math.sin(u * 5) * 0.12, 0)
	for p, c in live.rest do
		p.CFrame = move * c
	end
end

local function trailStart(slot)
	local _, rest = modelOf(slot.icon)
	return { rest = rest, t = 0 }
end

local function bannerStart(slot)
	local cloth = slot.icon and slot.icon:FindFirstChild("Cloth")
	local emblem = cloth and cloth:FindFirstChild("Emblem")
	if not emblem then
		error("no flag")
	end
	return { cloth = cloth, flair = Flair.banner(emblem, nil, (slot.it.look or {}).anim), t = 0 }
end

local function bannerStep(_, live, dt)
	live.t += dt
	live.cloth.Rotation = math.sin(live.t * 2.6) * 4
	live.flair:update(os.clock())
end

local function bannerStop(_, live)
	live.flair:destroy()
	live.cloth.Rotation = 0
end

local function titleStart(slot)
	local plate = slot.icon and slot.icon:FindFirstChild("Plate")
	if not plate then
		error("no plate")
	end
	return { plate = plate, rest = plate.Position, t = 0 }
end

local function titleStep(_, live, dt)
	live.t += dt
	live.plate.Rotation = math.sin(live.t * 2.2) * 2.5
	live.plate.Position = live.rest + UDim2.fromOffset(0, math.sin(live.t * 3) * 2)
end

local function titleStop(_, live)
	live.plate.Rotation = 0
	live.plate.Position = live.rest
end

local KINDS = {
	effect = { start = effectStart, step = effectStep, stop = effectStop },
	skin = { start = bowStart, step = bowStep, stop = restore },
	sword = { start = swordStart, step = swordStep, stop = swordStop },
	trail = { start = trailStart, step = trailStep, stop = restore },
	banner = { start = bannerStart, step = bannerStep, stop = bannerStop },
	title = { start = titleStart, step = titleStep, stop = titleStop },
}

-- Playing ------------------------------------------------------------------------------------------------------
local function setCovered(slot, playing)
	if slot.it.kind == "effect" and slot.icon then
		slot.icon.Visible = not playing -- (the stage stands in for the still picture)
	end
	for _, c in slot.opts.cover or {} do
		pcall(function()
			c.Visible = not playing
		end)
	end
end

local function stopSlot(slot)
	local live = slot.live
	if not live then
		return
	end
	slot.live = nil
	pcall(KINDS[slot.kind].stop, slot, live)
	setCovered(slot, false)
end

local function startSlot(slot)
	local ok, live = pcall(KINDS[slot.kind].start, slot)
	if not ok or not live then
		slot.broken = true -- (the still picture stays)
		return
	end
	slot.live = live
	setCovered(slot, true)
end

-- which ones play: on screen, a dialog's first (and then only those), in the order they were made, within budget
local function pick()
	local shown, top = {}, false
	for _, s in slots do
		if not s.broken and onScreen(s.box) then
			table.insert(shown, s)
			top = top or s.opts.priority == true
		end
	end
	table.sort(shown, function(a, b)
		local pa, pb = a.opts.priority == true, b.opts.priority == true
		if pa ~= pb then
			return pa
		end
		return a.n < b.n
	end)
	local want, left = {}, budget()
	for _, s in shown do
		local cost = COST[s.kind] or 1
		if (not top or s.opts.priority) and cost <= left then
			want[s] = true
			left -= cost
		end
	end
	for _, s in slots do
		if s.live and not want[s] then
			stopSlot(s)
		end
	end
	for s in want do
		if not s.live then
			startSlot(s)
		end
	end
end

function ItemPreview.step(dt)
	dt = math.clamp(dt or 1 / 60, 0, 1 / 15)
	for i = #slots, 1, -1 do
		local s = slots[i]
		if not s.box.Parent or not s.box:IsDescendantOf(game) then
			stopSlot(s)
			table.remove(slots, i)
		end
	end
	pickIn -= dt
	if pickIn <= 0 then
		pickIn = PICK_EVERY
		pick()
	end
	for _, s in slots do
		if s.live then
			local ok, err = pcall(KINDS[s.kind].step, s, s.live, dt)
			if not ok then
				warn("[ItemPreview] " .. tostring(s.it.key) .. ": " .. tostring(err))
				stopSlot(s)
				s.broken = true
			end
		end
	end
	if #slots == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function ItemPreview.attach(box, it, opts)
	if typeof(box) ~= "Instance" or type(it) ~= "table" or not KINDS[it.kind] then
		return nil
	end
	order += 1
	local slot = {
		box = box,
		it = it,
		kind = it.kind,
		opts = opts or {},
		icon = box:FindFirstChild("Icon"),
		n = order,
	}
	table.insert(slots, slot)
	pickIn = 0 -- (look again on the next frame)
	if not stepping then
		stepping = RunService.RenderStepped:Connect(ItemPreview.step)
	end
	return slot
end

function ItemPreview.stop()
	for _, s in slots do
		stopSlot(s)
	end
	slots = {}
	if stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function ItemPreview.running()
	local n = 0
	for _, s in slots do
		if s.live then
			n += 1
		end
	end
	return n
end

function ItemPreview.slots()
	return #slots
end

-- (tests) what the playing ones cost together, and how many couldn't be built
function ItemPreview.load()
	local n = 0
	for _, s in slots do
		if s.live then
			n += COST[s.kind] or 1
		end
	end
	return n
end
function ItemPreview.broken()
	local n = 0
	for _, s in slots do
		if s.broken then
			n += 1
		end
	end
	return n
end

ItemPreview.budget = budget

return ItemPreview

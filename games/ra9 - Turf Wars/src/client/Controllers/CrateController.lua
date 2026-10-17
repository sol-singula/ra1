--[[
The Crate, as the lobby shows it (lobby only: Modes = { "lobby" }; CrateService rolls, Data/Crate has the odds and
the pool, Data/Shop.CRATE the prices). Drawn on each client (nothing crosses the network but the spin and its
result), in the game's plain box style:

  * the crate on its stand (Crate.ANCHOR): a dark box with a gold band and a lid, a ? on every side, turning slowly
    and bobbing; a prompt on it (SPIN) and a sign over it with the prices and the odds
  * the rack beside it: the whole pool laid out on five shelves, a kind a shelf (sword skins stood on their points,
    bows standing, trails as little arrows, kill effects as small floating bursts, banners as little flags), each
    with its name and rarity over it, so you can walk along and look at what's in there; the sword skins alive
    (FX/Flair.sword), the floating ones turning
  * the panel: THE CRATE, the odds line, SPIN for Shards or for Robux; the spin: the crate shakes and its lid pops,
    the pool flicks past like a slot reel for 4.5 s, slows, and lands on the win with a burst in its rarity's
    colour (fireworks over the crate for a legendary); the result card with its live picture, EQUIP and SPIN AGAIN

Phone-cheap: plain parts, one billboard an item (gone past 40 studs), the rack's bits updated only when you're near,
the reel's cards made for the spin and gone after it; everything built here is one Folder (CrateController.clear).

  CrateController.open()   .close()   .spin("shards" | "robux")   .state() -> nil | "offer" | "waiting" | "spinning"
                           | "result"   .refs   .result()   .rack() -> { { key, item, parts } }   .build()   .clear()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Crate = require(ReplicatedStorage.Shared.Data.Crate)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local SwordSkins = require(ReplicatedStorage.Shared.SwordSkins)
local Store = require(script.Parent.Parent.Store)
local Bus = require(script.Parent.Parent.UI.Bus)
local Icons = require(script.Parent.Parent.UI.Icons)
local ItemPreview = require(script.Parent.Parent.UI.ItemPreview)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local Flair = require(script.Parent.Parent.FX.Flair)
local AudioController = require(script.Parent.AudioController)
local FireworksController = require(script.Parent.FireworksController)

local CrateController = { Name = "CrateController", Order = 49, Modes = { "lobby" } }

local C = Theme.Color
local GOLD = Icons.GOLD
local INK = Color3.fromRGB(36, 36, 44)
local WHITE = Color3.fromRGB(250, 250, 250)
local RARITY = { common = "COMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" }
local RARITY_COLOR = {
	common = Color3.fromRGB(140, 142, 150),
	rare = Color3.fromRGB(35, 110, 245),
	epic = Color3.fromRGB(150, 90, 240),
	legendary = Color3.fromRGB(240, 160, 20),
}
local KIND_TITLE =
	{ sword = "SWORD SKINS", skin = "BOWS", trail = "TRAILS", effect = "KILL EFFECTS", banner = "BANNERS" }
local SPIN_SECONDS = 4.5
local SPIN_SECONDS_LITE = 1.2 -- (Reduced Motion)
local CARD_W, CARD_GAP, CARDS, WIN_AT = 110, 6, 24, 21 -- (the reel: its cards, and which one the win is)
local W, H = 560, 340 -- the panel (design pixels)
local FAR = 90 -- studs: past this the rack's bits rest

local player = Players.LocalPlayer
local refs = {}
CrateController.refs = refs
local folder -- everything in the world
local crate -- { base, body, band, lid, parts }
local rack = { items = {}, anim = {}, swords = {} }
local gui, state, result, reel
local prompt
local stepping

local function team()
	return Store.team() or "red"
end

local function profile()
	return Store.get("profile") or {}
end

-- The world --------------------------------------------------------------------------------------------------------
local function part(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function words(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextScaled = true
	l.Font = Theme.Display
	l.TextColor3 = color or WHITE
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0.2
	for k, v in props or {} do
		l[k] = v
	end
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = size
	fit.Parent = l
	l.Parent = parent
	return l
end

-- A name and its rarity over a thing, gone past 40 studs
local function label(adornee, name, rarity, height)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Adornee = adornee
	g.Size = UDim2.new(1.7, 0, 0.6, 0) -- (in studs: it shrinks with distance, so the row's labels never pile up)
	g.StudsOffset = Vector3.new(0, height or 2, 0)
	g.MaxDistance = 40
	g.AlwaysOnTop = false
	g.LightInfluence = 0
	words(g, name, 18, WHITE, { Name = "Name", Size = UDim2.new(1, 0, 0, 24) })
	words(g, RARITY[rarity] or "", 13, RARITY_COLOR[rarity] or WHITE, {
		Name = "Rarity",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
	})
	g.Parent = adornee
	return g
end

local function face(p, normal, text, color)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Face"
	sg.Face = normal
	sg.LightInfluence = 0
	words(sg, text, 200, color)
	sg.Parent = p
	return sg
end

-- The pieces of a model moved as one: every part's CFrame from `at` (its own in the model's frame), sizes by k
local function placeModel(model, at, k)
	k = k or 1
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			p.Size = p.Size * k
			p.CFrame = at * (CFrame.new(cf.Position * k) * cf.Rotation)
		end
	end
end

local function buildCrate()
	local a = Crate.ANCHOR + Vector3.new(0, Crate.STAND, 0)
	local base = CFrame.new(a + Vector3.new(0, 1.3, 0))
	local m = Instance.new("Model")
	m.Name = "CrateBox"
	local body = part("Body", Vector3.new(3, 2.2, 3), INK, nil, m)
	local band = part("Band", Vector3.new(3.1, 0.36, 3.1), GOLD, nil, m)
	local lid = part("Lid", Vector3.new(3.3, 0.5, 3.3), Color3.fromRGB(58, 58, 68), nil, m)
	local knob = part("Knob", Vector3.new(0.6, 0.3, 0.6), GOLD, Enum.Material.Neon, m)
	for _, n in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		face(body, n, "?", GOLD)
	end
	crate = {
		base = base,
		body = body,
		band = band,
		lid = lid,
		knob = knob,
		-- (each part's place in the crate's frame)
		parts = {
			{ body, CFrame.new(0, 0, 0) },
			{ band, CFrame.new(0, -0.3, 0) },
			{ lid, CFrame.new(0, 1.35, 0) },
			{ knob, CFrame.new(0, 1.75, 0) },
		},
		shake = 0,
		pop = 0,
	}
	m.Parent = folder
	-- the sign over it: the name, the prices, the odds
	local g = Instance.new("BillboardGui")
	g.Name = "Sign"
	g.Adornee = body
	g.Size = UDim2.fromOffset(260, 86)
	g.StudsOffset = Vector3.new(0, 3.4, 0)
	g.MaxDistance = 80
	g.LightInfluence = 0
	words(g, "THE CRATE", 30, GOLD, { Name = "Title", Size = UDim2.new(1, 0, 0, 36) })
	words(g, `SPIN  ◆ {Crate.PRICE}  or  {Format.robux(Crate.PRODUCT.robux)}`, 17, WHITE, {
		Name = "Prices",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 24),
	})
	words(g, Crate.oddsLine(), 12, Color3.fromRGB(200, 200, 210), {
		Name = "Odds",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 20),
	})
	g.Parent = body
	-- the prompt: a step up to it and SPIN
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "SPIN"
	prompt.ObjectText = "THE CRATE"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		CrateController.open()
	end)
end

local function placeCrate(t, dt)
	if not crate then
		return
	end
	crate.shake = math.max(0, crate.shake - dt * 0.4)
	crate.pop = math.max(0, crate.pop - dt * 0.5)
	local sh = crate.shake
	local jitter = sh > 0
			and Vector3.new(
				math.sin(t * 61) * 0.12 * sh,
				math.abs(math.sin(t * 47)) * 0.1 * sh,
				math.cos(t * 53) * 0.12 * sh
			)
		or Vector3.zero
	local cf = crate.base
		* CFrame.new(jitter + Vector3.new(0, math.sin(t * 1.6) * 0.12, 0))
		* CFrame.Angles(0, t * 0.6, 0)
	for _, e in crate.parts do
		local p, off = e[1], e[2]
		if p == crate.lid or p == crate.knob then
			-- (the lid pops up and tips while the reel turns)
			local pop = math.sin(math.min(1, crate.pop) * math.pi) * 0.9
			p.CFrame = cf * off * CFrame.new(0, pop, 0) * CFrame.Angles(pop * 0.4, 0, 0)
		else
			p.CFrame = cf * off
		end
	end
end

-- The rack: a shelf a kind, the pool along it
local function buildRack()
	local a = Crate.ANCHOR
	local tm = team()
	local m = Instance.new("Model")
	m.Name = "Rack"
	for row, kind in Crate.KINDS do
		local items = {}
		for _, key in Crate.pool do
			local it = Cosmetics.get(key)
			if it and it.kind == kind then
				table.insert(items, it)
			end
		end
		table.sort(items, function(x, y)
			local rx, ry = table.find(Cosmetics.RARITIES, x.rarity), table.find(Cosmetics.RARITIES, y.rarity)
			if rx ~= ry then
				return rx < ry
			end
			return x.name < y.name
		end)
		local n = #items
		local z = a.Z - 7 - (row - 1) * 4
		local x0 = a.X + 6
		local len = n * 1.8 + 0.6
		local shelf = part("Shelf", Vector3.new(len, 0.4, 1.6), Color3.fromRGB(225, 227, 232), nil, m)
		shelf.CFrame = CFrame.new(x0 + len / 2 - 1.2, 0.2, z)
		for _, sx in { x0 - 0.9, x0 + len - 1.5 } do
			part("Leg", Vector3.new(0.3, 0.2, 1.6), INK, nil, m).CFrame = CFrame.new(sx, 0.5, z)
		end
		local sign = part("Sign", Vector3.new(0.2, 1.1, 2.4), INK, nil, m)
		sign.CFrame = CFrame.new(x0 - 2.2, 1.15, z)
		face(sign, Enum.NormalId.Right, KIND_TITLE[kind] or string.upper(kind), WHITE)
		face(sign, Enum.NormalId.Left, KIND_TITLE[kind] or string.upper(kind), WHITE)
		for j, it in items do
			local x = x0 + (j - 1) * 1.8
			local holder = Instance.new("Model")
			holder.Name = it.key
			local entry = { key = it.key, item = it, holder = holder, parts = {} }
			local anchor
			if kind == "sword" then
				local sword = SwordSkins.build(holder, it.look, tm, { scale = 0.7 })
				SwordSkins.place(sword, CFrame.new(x, 1.15, z) * CFrame.Angles(math.rad(90), 0, 0))
				anchor = sword.parts[1].part
				local look = it.look or {}
				if look.anim or look.particles or look.sticker then
					table.insert(rack.swords, Flair.sword(sword, look, tm))
				end
				entry.height = 3.2
			elseif kind == "banner" then
				local pole = part("Pole", Vector3.new(0.12, 2.4, 0.12), INK, nil, holder)
				pole.CFrame = CFrame.new(x - 0.5, 1.6, z)
				local cloth = part("Cloth", Vector3.new(1.0, 0.7, 0.08), Constants.TEAM_COLOR[tm], nil, holder)
				cloth.CFrame = CFrame.new(x, 2.4, z)
				local emblem = (it.look or {}).emblem or "★"
				face(cloth, Enum.NormalId.Front, emblem, WHITE)
				face(cloth, Enum.NormalId.Back, emblem, WHITE)
				anchor = pole
				entry.height = 2
			else
				local model = Icons.model(it, tm)
				local anim
				if kind == "skin" then
					placeModel(model, CFrame.new(x, 1.75, z), 0.6)
				elseif kind == "trail" then
					-- (the arrow flies toward you, its streak behind it, a little above the shelf)
					anim = { at = CFrame.new(x, 1.5, z), kind = "bob", seed = j, rest = {} }
					placeModel(model, anim.at * CFrame.Angles(0, math.rad(-90), 0), 0.4)
				else
					anim = { at = CFrame.new(x, 1.6, z), kind = "spin", seed = j, rest = {} }
					placeModel(model, anim.at, 0.35)
				end
				for _, p in model:GetChildren() do
					if p.Shape ~= nil and p.Shape ~= Enum.PartType.Block then
						-- (a burst's core, a cylinder: boxes only out here, like everything else in the game)
						p.Shape = Enum.PartType.Block
					end
					p.Parent = holder
					anchor = anchor or p
					if anim then
						anim.rest[p] = anim.at:ToObjectSpace(p.CFrame) -- (its seat, to turn and bob about)
					end
				end
				model:Destroy()
				if anim then
					table.insert(rack.anim, anim)
				end
				entry.height = kind == "skin" and 2.2 or 1.4
			end
			for _, p in holder:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(entry.parts, p)
				end
			end
			if anchor then
				label(anchor, it.name, it.rarity, entry.height)
			end
			holder.Parent = m
			table.insert(rack.items, entry)
		end
	end
	m.Parent = folder
end

local function stepRack(t, frame)
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	local far = eye and (eye - Crate.ANCHOR).Magnitude > FAR
	if far and frame % 12 ~= 0 then
		return
	end
	for _, e in rack.anim do
		local turn = e.kind == "spin" and CFrame.Angles(0, t * 0.9 + e.seed, 0) or CFrame.new()
		local lift = Vector3.new(0, math.sin(t * 1.7 + e.seed) * 0.12, 0)
		local at = e.at * CFrame.new(lift) * turn
		for p, rest in e.rest do
			p.CFrame = at * rest
		end
	end
	for _, h in rack.swords do
		h:update(t)
	end
end

function CrateController.build()
	if folder then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "Crate"
	folder.Parent = workspace
	buildCrate()
	buildRack()
	return folder
end

function CrateController.clear()
	for _, h in rack.swords do
		h:destroy()
	end
	rack = { items = {}, anim = {}, swords = {} }
	crate = nil
	prompt = nil
	if folder then
		folder:Destroy()
		folder = nil
	end
end

function CrateController.rack()
	return rack.items
end

-- The panel ---------------------------------------------------------------------------------------------------------
local function text(parent, name, s, x, y, w, h, size, color, align, font)
	return Theme.text({
		Name = name,
		Text = s,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		TextSize = size,
		TextColor3 = color or C.ink,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Font = font,
		Parent = parent,
	})
end

local function button(parent, name, s, x, y, w, h, style, onClick)
	local bg = style == "gold" and GOLD or (style == "dark" and C.ink or Color3.fromRGB(232, 232, 234))
	local b = Theme.button({
		Name = name,
		Text = s,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = bg,
		TextColor3 = style == "dark" and C.white or C.ink,
		TextSize = 17,
		dark = style ~= "dark",
		Parent = parent,
	})
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function picture(parent, name, x, y, w, h)
	local box = Theme.new("Frame", {
		Name = name or "Preview",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(236, 238, 243),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, { Theme.corner(6) })
	box:SetAttribute("Art", true)
	return box
end

local function setState(s)
	state = s
	if not refs.offer then
		return
	end
	refs.offer.Visible = s == "offer"
	refs.reelBox.Visible = s == "waiting" or s == "spinning"
	refs.resultBox.Visible = s == "result"
end

local function buildGui()
	if gui then
		return
	end
	gui = Theme.screen("Crate", 12, player:WaitForChild("PlayerGui"))
	gui.Enabled = false
	local card = Theme.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Theme.corner(14), Theme.stroke(3, C.ink) })
	refs.card = card
	Layout.modal("crate", card)
	local head = Theme.new("Frame", {
		Name = "Head",
		Size = UDim2.fromOffset(W, 44),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(12) })
	text(head, "Title", "THE CRATE", 16, 8, 300, 28, 22, GOLD, nil, Theme.Display)
	refs.close = Theme.closeButton(head, CrateController.close, { Position = UDim2.fromOffset(W - 40, 4) })
	refs.odds = text(
		card,
		"Odds",
		"ODDS  ·  " .. Crate.oddsLine(),
		16,
		50,
		W - 32,
		18,
		12,
		C.muted,
		Enum.TextXAlignment.Center
	)
	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.fromOffset(W - 32, H - 84),
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- (the result's burst stays inside the card)
		Parent = card,
	})
	local bw = W - 32

	-- the offer: the crate drawn with frames, what's inside, SPIN for Shards or for Robux
	local offer =
		Theme.new("Frame", { Name = "Offer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	refs.offer = offer
	local pic = picture(offer, "Preview", 0, 10, 160, 150)
	Theme.new("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(96, 76),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Parent = pic,
	}, { Theme.corner(6) })
	Theme.new("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(102, 12),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = pic,
	})
	Theme.new("Frame", {
		Name = "Lid",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(106, 18),
		BackgroundColor3 = Color3.fromRGB(58, 58, 68),
		BorderSizePixel = 0,
		Parent = pic,
	}, { Theme.corner(4) })
	Theme.text({
		Name = "Mark",
		Text = "?",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 40),
		fit = 40,
		Font = Theme.Display,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = pic,
	})
	text(offer, "What", "WHAT'S INSIDE?", 176, 10, bw - 176, 26, 20, C.ink, nil, Theme.Display)
	text(
		offer,
		"Line",
		`One of {#Crate.pool} cosmetics from the rack beside it: sword skins, bows, trails, kill effects and banners. Never one you already own; own them all and a spin gives half its Shards back.`,
		176,
		40,
		bw - 176,
		62,
		12,
		C.muted
	)
	refs.have = text(offer, "Have", "", 176, 104, bw - 176, 18, 12, C.ink)
	refs.spinShards = button(offer, "SpinShards", `SPIN  ◆ {Crate.PRICE}`, 176, 126, 168, 44, "dark", function()
		CrateController.spin("shards")
	end)
	refs.spinRobux = button(
		offer,
		"SpinRobux",
		`SPIN  {Format.robux(Crate.PRODUCT.robux)}`,
		352,
		126,
		bw - 352,
		44,
		"gold",
		function()
			CrateController.spin("robux")
		end
	)
	refs.note = text(offer, "Note", "", 176, 176, bw - 176, 36, 12, Color3.fromRGB(200, 40, 50))

	-- the reel: the pool flicking past a gold marker
	local reelBox =
		Theme.new("Frame", { Name = "Reel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	refs.reelBox = reelBox
	local window = Theme.new("Frame", {
		Name = "Window",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.fromOffset(bw, 150),
		BackgroundColor3 = Color3.fromRGB(236, 238, 243),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = reelBox,
	}, { Theme.corner(8) })
	window:SetAttribute("Art", true)
	refs.window = window
	refs.strip = Theme.new(
		"Frame",
		{ Name = "Strip", Size = UDim2.fromOffset(10, 150), BackgroundTransparency = 1, Parent = window }
	)
	for _, y in { 0, 150 - 14 } do
		Theme.new("Frame", {
			Name = y == 0 and "MarkTop" or "MarkBottom",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(bw / 2, y),
			Size = UDim2.fromOffset(8, 14),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = window,
		})
	end
	refs.caption =
		text(reelBox, "Caption", "SPINNING...", 0, 190, bw, 30, 20, C.ink, Enum.TextXAlignment.Center, Theme.Display)

	-- the result: the burst, the win's live picture, its name and rarity, EQUIP and SPIN AGAIN
	local resultBox =
		Theme.new("Frame", { Name = "Result", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	refs.resultBox = resultBox
	refs.burst = Theme.new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(85, 80),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = resultBox,
	})
	refs.burst:SetAttribute("Art", true)
	refs.resultPic = picture(resultBox, "Preview", 0, 10, 170, 140)
	refs.resultPic.ZIndex = 2
	refs.band = text(resultBox, "Band", "", 186, 12, bw - 186, 22, 14, GOLD, nil, Theme.Display)
	refs.name = text(resultBox, "Name", "", 186, 36, bw - 186, 36, 26, C.ink, nil, Theme.Display)
	refs.resultLine = text(resultBox, "Line", "", 186, 76, bw - 186, 40, 13, C.muted)
	refs.equip = button(resultBox, "Equip", "EQUIP", 186, 126, 160, 44, "dark", function()
		if result and not result.dup then
			Net.send("Settings", "equip", { kind = result.kind, key = result.key })
			Bus.Tap:Fire("crate_equip")
			refs.equip.Text = "EQUIPPED ✓"
		end
	end)
	refs.again = button(resultBox, "Again", "SPIN AGAIN", 356, 126, bw - 356, 44, "gold", function()
		Bus.Tap:Fire("crate_again")
		CrateController.offer()
	end)
	refs.seeOdds = text(
		resultBox,
		"SeeOdds",
		"See the odds above · every item's on the rack",
		0,
		196,
		bw,
		18,
		11,
		C.muted,
		Enum.TextXAlignment.Center
	)
end

-- The offer, with what they have in Shards
function CrateController.offer()
	buildGui()
	ItemPreview.stop()
	result = nil
	refs.note.Text = ""
	refs.have.Text = `You have ◆ {Format.commas(profile().shards or 0)}`
	setState("offer")
end

function CrateController.open()
	buildGui()
	Layout.claimPanel("crate", CrateController.close)
	gui.Enabled = true
	refs.card.Visible = true
	Layout.setPanel(true)
	CrateController.offer()
	pcall(Net.send, "Analytics", "ui", { what = "crate_open" })
end

function CrateController.close()
	if not gui then
		return
	end
	gui.Enabled = false
	refs.card.Visible = false
	ItemPreview.stop()
	if refs.strip then
		refs.strip:ClearAllChildren()
	end
	reel = nil
	result = nil
	state = nil
	Layout.setPanel(false)
end

function CrateController.spin(how)
	if state ~= "offer" and state ~= "result" then
		return false
	end
	if how == "shards" and (profile().shards or 0) < Crate.PRICE then
		refs.note.Text = `You need {Crate.PRICE - (profile().shards or 0)} more Shards. The shop sells them!`
		return false
	end
	ItemPreview.stop()
	result = nil
	setState("waiting")
	refs.caption.Text = "..."
	refs.strip:ClearAllChildren()
	reel = { waitUntil = os.clock() + 8 }
	Net.send("Crate", "spin", how)
	Bus.Tap:Fire("crate_spin_" .. tostring(how))
	return true
end

-- The reel's cards: the pool at random, the win where the reel will land
local function buildReel(win)
	refs.strip:ClearAllChildren()
	local keys = {}
	for i = 1, CARDS do
		keys[i] = Crate.pool[math.random(1, #Crate.pool)]
	end
	keys[WIN_AT] = win.key
	local cards = {}
	for i, key in keys do
		local it = Cosmetics.get(key)
		local x = (i - 1) * (CARD_W + CARD_GAP)
		local card = Theme.new("Frame", {
			Name = "Card" .. i,
			Position = UDim2.fromOffset(x, 8),
			Size = UDim2.fromOffset(CARD_W, 134),
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			Parent = refs.strip,
		}, { Theme.corner(6), Theme.stroke(2, RARITY_COLOR[it.rarity] or C.muted) })
		card:SetAttribute("Art", true)
		local pic = picture(card, "Preview", 6, 6, CARD_W - 12, 84)
		Icons.cosmetic(it, team(), {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(CARD_W - 16, 80),
			Parent = pic,
		})
		text(card, "Name", it.name, 4, 94, CARD_W - 8, 20, 12, C.ink, Enum.TextXAlignment.Center, Theme.Display)
		text(
			card,
			"Rarity",
			RARITY[it.rarity] or "",
			4,
			112,
			CARD_W - 8,
			16,
			10,
			RARITY_COLOR[it.rarity],
			Enum.TextXAlignment.Center
		)
		cards[i] = card
	end
	refs.strip.Size = UDim2.fromOffset(CARDS * (CARD_W + CARD_GAP), 150)
	return cards
end

local function easeOut(f)
	return 1 - (1 - f) ^ 3
end

local function startReel(r)
	local seconds = Theme.reducedMotion() and SPIN_SECONDS_LITE or SPIN_SECONDS
	local cx = (W - 32) / 2
	reel = {
		cards = buildReel(r),
		t0 = os.clock(),
		seconds = seconds,
		from = cx - CARD_W / 2 - 2 * (CARD_W + CARD_GAP),
		to = cx - CARD_W / 2 - (WIN_AT - 1) * (CARD_W + CARD_GAP),
		under = 0,
		done = false,
	}
	setState("spinning")
	refs.caption.Text = "SPINNING..."
	if crate then
		crate.shake = 1.4
		crate.pop = 1.6
	end
	Layout.modal("crate", refs.card)
end

local function landed(r)
	local it = Cosmetics.get(r.key)
	result = r
	setState("result")
	refs.band.Text = `{RARITY[r.rarity] or ""}  ·  {Cosmetics.KIND_NAME[r.kind] or string.upper(r.kind)}`
	refs.band.TextColor3 = RARITY_COLOR[r.rarity] or GOLD
	refs.name.Text = r.name
	if r.dup then
		refs.resultLine.Text = `DUPLICATE: you had it already. ◆ {r.refund} back.`
		refs.equip.Text = "YOURS ALREADY"
	else
		refs.resultLine.Text = r.paid == "robux" and "NEW! It's yours for good. EQUIP wears it now."
			or "NEW! It's yours. EQUIP wears it now."
		refs.equip.Text = "EQUIP"
	end
	refs.resultPic:ClearAllChildren()
	Theme.corner(6).Parent = refs.resultPic
	if it then
		Icons.cosmetic(it, team(), {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(166, 136),
			Parent = refs.resultPic,
		})
		ItemPreview.attach(refs.resultPic, it, { priority = true })
	end
	refs.burst.BackgroundColor3 = RARITY_COLOR[r.rarity] or GOLD
	refs.burst.Size = UDim2.fromOffset(0, 0)
	refs.burst.BackgroundTransparency = 0.2
	reel = { burstAt = os.clock(), rarity = r.rarity }
	-- (the world: a shower of blocks off the crate; fireworks over it for a legendary)
	if crate then
		for _ = 1, Flair.lite() and 6 or 14 do
			Flair.drop("blocks", crate.body.Position + Vector3.new(0, 1.5, 0), team())
		end
	end
	if r.rarity == "legendary" then
		pcall(FireworksController.show, Crate.ANCHOR, GOLD, {
			seconds = 5,
			radius = 18,
			tilt = false,
			flash = false,
		})
		pcall(AudioController.play, "victory")
	else
		pcall(AudioController.play, r.dup and "refused" or "built")
	end
end

local function stepReel(t)
	if not reel then
		return
	end
	if reel.burstAt then
		-- the burst behind the picture: out, and gone
		local k = (t - reel.burstAt) / 0.7
		if k >= 1 then
			refs.burst.BackgroundTransparency = 1
			reel = nil
		else
			refs.burst.Size = UDim2.fromOffset(60 + k * 260, 60 + k * 260)
			refs.burst.BackgroundTransparency = 0.2 + k * 0.8
			refs.burst.Rotation = 45 + k * 40
		end
		return
	end
	if reel.waitUntil then
		if t > reel.waitUntil then
			-- (nothing came back: the server said why in a toast)
			CrateController.offer()
		end
		return
	end
	local f = math.min(1, (t - reel.t0) / reel.seconds)
	local x = reel.from + (reel.to - reel.from) * easeOut(f)
	refs.strip.Position = UDim2.fromOffset(x, 0)
	-- (the card under the marker: a tick as each one passes, a little pop on it)
	local cx = (W - 32) / 2
	local under = math.floor((cx - x) / (CARD_W + CARD_GAP)) + 1
	if under ~= reel.under then
		reel.under = under
		pcall(AudioController.play, "click", 0.9 + f * 0.3, 0.5)
		local card = reel.cards[under]
		if card then
			card.Position = UDim2.fromOffset((under - 1) * (CARD_W + CARD_GAP), 4)
			local prev = reel.cards[under - 1]
			if prev then
				prev.Position = UDim2.fromOffset((under - 2) * (CARD_W + CARD_GAP), 8)
			end
		end
	end
	if f >= 1 and not reel.done then
		reel.done = true
		landed(reel.result)
	end
end

function CrateController.state()
	return state
end

function CrateController.result()
	return result
end

local frame = 0
local function step(dt)
	frame += 1
	local t = os.clock()
	placeCrate(t, dt)
	if folder then
		stepRack(t, frame)
	end
	stepReel(t)
end

function CrateController:init()
	Net.listen("Crate", function(r)
		if type(r) ~= "table" or type(r.key) ~= "string" then
			return
		end
		if state == "waiting" or state == "spinning" then
			buildGui()
			local keep = r
			startReel(keep)
			reel.result = keep
		end
	end)
	if Constants.MODE ~= "lobby" then
		return
	end
	CrateController.build()
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

return CrateController

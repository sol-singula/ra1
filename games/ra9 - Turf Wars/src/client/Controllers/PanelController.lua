--[[
The panel (B, or the SHOP button; Tab opens it on PLAYERS): five tabs, SUPERHOT-plain (white cards, black type,
the team's colour) with a picture on every card:

  PLAYERS  everyone on the server by team (VIP, your party), INVITE to party up; Roblox's own Tab list is off
  SHOP     "Pick something fun!": LEGENDARY FX (every Robux-only cosmetic on a big animated card: a turning
           rainbow edge, a sweeping shine, its emoji bobbing, a funny line and the Robux price, sideways in one
           row), the week's bundle as the FEATURED card, today's 4 items, Shard packs (a bigger
           pile of gems for a bigger pack), the Turf Pass and +1 TIER, the Starter Pack (and the Shard Club when
           it's on); timers to the next rotation
  PASS     the season's Turf Pass explained in a line, your tier and XP, GET THE PASS and +1 TIER, and the tiers as
           a track you scroll across: the FREE row and the gold PASS row, YOU ARE HERE, CLAIM on what's ready
  LOCKER   everything of a kind (trail, bow, kill effect, banner, title): yours to wear, or how to get it
  GOALS    VIP (earned, never bought) and how close you are, MVP, the goals and their rewards, and HOW TO PLAY
           (REPLAY: the first-game tutorial again)

Your Shards sit big at the top with a + that jumps to the packs. Spending Shards always asks first ("Buy Neon Trail
for 350?" YES / NO); not enough says how many more and offers the packs; a buy pops with confetti and NEW!, with
EQUIP NOW when it isn't worn yet. The first time the shop opens, a 3-step tour (your Shards, today's items, the
pass), skippable, remembered in the profile (settings.shopTour). Robux prices wear Roblox's own Robux icon.

While it's open the mouse is free, the HUD's middle steps aside (Layout.setPanel) and toasts show on the panel's own
line at the bottom. Every piece has its own slot (the numbers below), so nothing lands on anything (ClientSmoke
checks); the dialogs and the tour sit on a layer of their own over the body.

  PanelController.open(tab?)   .close()   .toggle()   .tab()   .refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Achievements = require(ReplicatedStorage.Shared.Data.Achievements)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Ladder = require(ReplicatedStorage.Shared.Data.Ladder)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local MemeArt = require(ReplicatedStorage.Shared.Data.MemeArt)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)
local Layout = require(script.Parent.Parent.UI.Layout)
local KillBanner = require(script.Parent.KillBannerController)

local PanelController = { Name = "PanelController", Order = 48 }

local C = Theme.Color
local LIGHT = Color3.fromRGB(232, 232, 234)
local GOLD = Icons.GOLD
local GOLD_SOFT = Color3.fromRGB(255, 241, 196)
local GREEN = Color3.fromRGB(46, 170, 90)
local player = Players.LocalPlayer

-- The geometry (design pixels): the panel sits under the top bar, clear of the corners (the kill feed and popup
-- stack on the right start at x 924 on a 1240 canvas, the panel ends at 920)
local P = { w = 600, h = 450, top = 96, head = 44, bodyY = 52, bodyH = 352, footY = 412, footH = 26 }
local W = 564 -- the body's content width (inside its scroll bar)
PanelController.P = P

local TABS = {
	{ "players", "PLAYERS" },
	{ "shop", "SHOP" },
	{ "pass", "PASS" },
	{ "locker", "LOCKER" },
	{ "goals", "GOALS" },
}
local RARITY = { common = "COMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" }
local RARITY_COLOR = {
	common = Color3.fromRGB(140, 142, 150),
	rare = Color3.fromRGB(35, 110, 245),
	epic = Color3.fromRGB(150, 90, 240),
	legendary = Color3.fromRGB(240, 160, 20),
}
local refs = {}
PanelController.refs = refs
local current = "shop"
local lockerKind = "trail"
local spotlight -- a cosmetic key the locker points at (a free gift: PanelController.showItem), until it's worn
local gui
local pending -- a purchase waiting for the server: { check = fn(profile), show = fn(), untilT }
local toured = false -- (the shop's tour shown this visit)

local function profile()
	return Store.get("profile") or {}
end

local function now()
	return workspace:GetServerTimeNow()
end

local money = Format.commas

local function span(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then
		return `{d}d {h}h`
	elseif h > 0 then
		return `{h}h {m}m`
	end
	return `{m}m`
end

local function text(parent, props)
	props.Parent = parent
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
end

local function frame(parent, name, x, y, w, h, color, edge)
	return Theme.new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(6), Theme.stroke(edge and 3 or 2, edge or C.ink) })
end

-- A button. style: true (or "dark") black, false/nil white, "gold", "green", "grey" (can't be pressed)
local STYLE = {
	dark = { C.ink, C.white },
	light = { C.white, C.ink },
	gold = { GOLD, C.ink },
	green = { GREEN, C.white },
	grey = { LIGHT, C.muted },
}
local function button(parent, name, label, x, y, w, h, style, onClick)
	local s = STYLE[style == true and "dark" or (style or "light")] or STYLE.light
	local b = Theme.new("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = s[1],
		Text = "",
		AutoButtonColor = style ~= "grey",
		Parent = parent,
	}, { Theme.corner(6), Theme.stroke(2, C.ink) })
	text(b, {
		Name = "Label",
		Text = label,
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.fromOffset(4, 3),
		fit = math.min(18, math.floor(h * 0.5)),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = s[2],
	})
	if style ~= "grey" then
		Theme.pressable(b)
	end
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- A big buy button with a price: Shards (the gem and the number) or Robux (Roblox's Robux icon and the number)
local function priceButton(parent, name, x, y, w, h, price, style, onClick)
	if price.robux then
		local b = button(parent, name, Format.robux(price.robux), x, y, w, h, style or "dark", onClick)
		b.Label.UITextSizeConstraint.MaxTextSize = math.floor(math.min(24, h * 0.6) * Theme.textFactor() + 0.5)
		return b
	end
	local b = button(parent, name, `{price.shards} Shards`, x, y, w, h, style or "dark", onClick)
	b.Label.Visible = false -- (the gem and the number say it)
	Theme.shards(b, price.shards, {
		Name = "Price",
		w = w - 12,
		h = math.floor(h * 0.64),
		Position = UDim2.fromOffset(6, math.floor(h * 0.18)),
		color = (STYLE[style or "dark"] or STYLE.dark)[2],
	})
	return b
end

local function label(parent, name, s, x, y, w, h, size, color, align, font)
	return text(parent, {
		Name = name,
		Text = s,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		fit = size or 13,
		TextColor3 = color or C.ink,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Font = font or Theme.Body,
	})
end

-- A picture box: a soft shaded backdrop with the picture (from build(box)) filling it. Its pieces sit on each other
-- on purpose, so the overlap checks treat it as one thing (Art)
local function picture(parent, x, y, w, h, build, bg)
	local box = Theme.new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = bg or Color3.fromRGB(236, 238, 243),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Theme.corner(5),
		Theme.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 199, 208)),
		}),
	})
	box:SetAttribute("Art", true)
	if build then
		build(box, w, h)
	end
	return box
end

local function fill(w, h, pad)
	pad = pad or 2
	return {
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.fromOffset(w - pad * 2, h - pad * 2),
	}
end

-- A cosmetic's picture (Icons.cosmetic) in a w x h box
local function preview(parent, it, x, y, w, h)
	return picture(parent, x, y, w, h, function(box)
		if it then
			local props = fill(w, h)
			props.Parent = box
			Icons.cosmetic(it, Store.team() or "red", props)
		end
	end)
end
PanelController.preview = preview

-- A padlock drawn with frames (a body and a shackle), centred at x, y
local function padlock(parent, x, y, s, color)
	local box = Theme.new("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(s, s),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	box:SetAttribute("Art", true)
	Theme.new("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.56, 0.6),
		BackgroundTransparency = 1,
		Parent = box,
	}, { Theme.corner("round"), Theme.stroke(math.max(2, s / 8), color or C.ink) })
	Theme.new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.86, 0.58),
		BackgroundColor3 = color or C.ink,
		BorderSizePixel = 0,
		Parent = box,
	}, { Theme.corner(math.max(2, math.floor(s / 7))) })
	return box
end

-- A green tick drawn with two bars
local function tick(parent, x, y, s)
	local box = Theme.new("Frame", {
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner("round"), Theme.stroke(2, C.white) })
	box:SetAttribute("Art", true)
	for i, b in { { 0.34, 0.6, 0.28, 45 }, { 0.58, 0.5, 0.52, -50 } } do
		Theme.new("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(b[1], b[2]),
			Size = UDim2.new(b[3], 0, 0, math.max(2, s / 8)),
			Rotation = b[4],
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			Parent = box,
		}, { Theme.corner("round") })
	end
	return box
end

-- The tabs' bodies ----------------------------------------------------------------------------------------------
local function section(body, name, s, y, note)
	label(body, name, s, 0, y, note and 300 or W, 20, 15, C.ink, nil, Theme.Display)
	if note then
		label(body, name .. "Note", note, 300, y + 2, W - 300, 16, 12, C.muted, Enum.TextXAlignment.Right)
	end
	return y + 26
end

local confirmBuy, notEnough, showPacks, celebrate, startTour -- (the dialogs, below)

-- A purchase asked for: when a profile from the server shows it went through (check), celebrate it (show). Set
-- before the request goes, so even an answer that comes straight back is seen.
local function waitFor(seconds, check, show)
	pending = { untilT = os.clock() + seconds, check = check, show = show }
end

-- The panel's moving bits (the premium cards' edges and shine, the legendary shimmer): stepped each frame while
-- their card is on screen, dropped when it's gone (the body is rebuilt on every refresh)
local anims = {} -- { inst, update = fn(t) }
local function animate(inst, update)
	table.insert(anims, { inst = inst, update = update })
end
PanelController.anims = anims

-- One of today's items or a locker card's action: WORN, WEAR, or its price
local function itemCard(body, i, key, x, y, cw)
	local p = profile()
	local it = Cosmetics.get(key)
	-- (the rarer, the louder: an edge in the rarity's colour from epic up, a shimmer on the legendary ones)
	local glow = (it.rarity == "epic" or it.rarity == "legendary") and RARITY_COLOR[it.rarity] or nil
	local card = frame(body, "Item" .. i, x, y, cw, 200, nil, glow)
	if it.rarity == "legendary" then
		card.ClipsDescendants = true
		local shimmer = Theme.new("Frame", {
			Name = "Shimmer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(-0.3, 0, 0.5, 0),
			Size = UDim2.new(0, 26, 1.6, 0),
			Rotation = 20,
			BackgroundColor3 = Color3.fromRGB(255, 236, 160),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = card,
		})
		shimmer:SetAttribute("Layer", true) -- (a light over the card on purpose)
		local phase = i * 0.5
		animate(card, function(t)
			local s = ((t + phase) % 2.6) / 0.8
			shimmer.Position = UDim2.new(-0.3 + 1.6 * math.min(s, 1), 0, 0.5, 0)
			shimmer.Visible = s < 1
		end)
	end
	local band = Theme.new("Frame", {
		Name = "Band",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(cw, 22),
		BackgroundColor3 = RARITY_COLOR[it.rarity] or C.muted,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(6) })
	label(
		band,
		"Rarity",
		RARITY[it.rarity] or "",
		8,
		3,
		cw - 16,
		16,
		12,
		C.white,
		Enum.TextXAlignment.Center,
		Theme.Display
	)
	local owned = Locker.owns(p, key)
	local worn = (p.equipped or {})[it.kind] == key
	local pic = preview(card, it, 8, 28, cw - 16, 88)
	if owned then
		tick(pic, cw - 30, 14, 20)
	end
	label(card, "Name", it.name, 8, 120, cw - 16, 22, 16, C.ink, Enum.TextXAlignment.Center, Theme.Display)
	label(
		card,
		"Line",
		Cosmetics.KIND_NAME[it.kind] .. (worn and "  ·  WORN" or (owned and "  ·  YOURS" or "")),
		8,
		142,
		cw - 16,
		14,
		11,
		C.muted,
		Enum.TextXAlignment.Center
	)
	local price = Shop.price(it)
	local function act()
		if worn then
			return
		elseif owned then
			Net.send("Settings", "equip", { kind = it.kind, key = key })
		else
			confirmBuy(it, price)
		end
	end
	if worn then
		button(card, "Buy", "WORN", 8, 160, cw - 16, 34, "grey")
	elseif owned then
		button(card, "Buy", "WEAR", 8, 160, cw - 16, 34, "light", act)
	else
		local afford = (p.shards or 0) >= price
		priceButton(card, "Buy", 8, 160, cw - 16, 34, { shards = price }, afford and "dark" or "light", act)
	end
	return card
end

-- The premium row -----------------------------------------------------------------------------------------------
-- Every Robux-only cosmetic (Shop.PREMIUM) on a big dark card: a rainbow edge that turns, a shine that sweeps
-- across, the picture bobbing with its emoji, a funny line, and the Robux price (OWNED / WEAR once it's yours).
-- The cards scroll sideways in one row, so the row is the same height on a phone.
local TAGLINE = {
	rbx_lightning = "Zeus called. He wants his kill back.",
	rbx_doge = "wow. such kill. much skill.",
	rbx_web = "Your friendly neighbourhood knockout.",
	rbx_oof = "The sound says it all.",
	rbx_bonk = "BONK. Straight to jail.",
	rbx_dance = "Lose? Dance it off.",
	rbx_blackhole = "Gone. Reduced to atoms.",
	rbx_heaven = "Send them up in style.",
	rbx_storm = "A bow that crackles.",
	rbx_dragon = "Gold. Wings. Respect.",
	rbx_thunder = "Every arrow brings the storm.",
	rbx_lightningbanner = "Your banner, electrified.",
	rbx_dogebanner = "much banner. very team.",
	rbx_crown = "For the king of the turf.",
}
local KIND_EMOJI = { skin = "🏹", trail = "☄️", title = "🏷️" }

local function emojiOf(it)
	local look = it.look or {}
	if it.kind == "effect" then
		return KillBanner.EMOJI[look.shape] or "✨"
	elseif it.kind == "banner" then
		return look.emblem or "★"
	end
	return KIND_EMOJI[it.kind] or "✨"
end

local function premiumRow(body, y)
	if #Shop.PREMIUM == 0 then
		return y
	end
	local p = profile()
	y = section(body, "PremiumLabel", "✨ LEGENDARY FX ✨", y, "Robux only · yours forever")
	local CW, CH = 168, 238
	local row = Theme.new("ScrollingFrame", {
		Name = "Premium",
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(W, CH + 14),
		CanvasSize = UDim2.fromOffset(#Shop.PREMIUM * (CW + 10) + 4, CH),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = body,
	})
	refs.premium = row
	refs.premiumCards = {}
	for i, prod in Shop.PREMIUM do
		local it = Cosmetics.get(prod.cosmetic)
		if it then
			local owned = Locker.owns(p, it.key)
			local worn = (p.equipped or {})[it.kind] == it.key
			local x = 2 + (i - 1) * (CW + 10)
			local card = Theme.new("Frame", {
				Name = "Premium_" .. it.key,
				Position = UDim2.fromOffset(x, 4),
				Size = UDim2.fromOffset(CW, CH),
				BackgroundColor3 = Color3.fromRGB(26, 22, 40),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = row,
			}, { Theme.corner(10) })
			card:SetAttribute("Key", it.key)
			-- the rainbow edge (a gradient on the stroke, turning)
			local edge = Theme.stroke(3, C.white)
			edge.Parent = card
			local hue = Theme.new("UIGradient", {
				Name = "Rainbow",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
					ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 230, 140)),
					ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
				}),
				Parent = edge,
			})
			-- the band: what it is
			local band = Theme.new("Frame", {
				Name = "Band",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(CW, 22),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Parent = card,
			})
			label(
				band,
				"Kind",
				(it.kind == "effect" and "KILL EFFECT" or Cosmetics.KIND_NAME[it.kind])
					.. "  ·  "
					.. (RARITY[it.rarity] or ""),
				6,
				3,
				CW - 12,
				16,
				11,
				C.ink,
				Enum.TextXAlignment.Center,
				Theme.Display
			)
			-- the picture, bobbing, its emoji big over it
			local pic = preview(card, it, 10, 28, CW - 20, 92)
			local emoji = text(pic, {
				Name = "Emoji",
				Text = emojiOf(it),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.78, 0.3),
				Size = UDim2.fromOffset(40, 40),
				fit = 34,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 3,
			})
			-- (the meme ones: their sticker art, big over the picture, bobbing with the emoji)
			local art = MemeArt.FOR_ITEM[it.key]
			if art then
				local img = Theme.new("ImageLabel", {
					Name = "Sticker",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(88, 88),
					ScaleType = Enum.ScaleType.Fit,
					Image = MemeArt.image(art),
					ZIndex = 2,
					Parent = pic,
				})
				local phase2 = i * 0.9
				animate(card, function(t)
					img.Rotation = math.sin(t * 2.4 + phase2) * 7
					img.Size = UDim2.fromOffset(88 + math.sin(t * 4 + phase2) * 5, 88 + math.sin(t * 4 + phase2) * 5)
				end)
			end
			if owned then
				tick(pic, CW - 34, 14, 20)
			end
			label(card, "Name", it.name, 8, 124, CW - 16, 24, 17, C.white, Enum.TextXAlignment.Center, Theme.Display)
			label(
				card,
				"Tagline",
				TAGLINE[it.key] or "",
				8,
				150,
				CW - 16,
				32,
				11,
				Color3.fromRGB(200, 196, 220),
				Enum.TextXAlignment.Center
			)
			local buy
			if worn then
				buy = button(card, "Buy", "WORN", 10, CH - 46, CW - 20, 36, "grey")
			elseif owned then
				buy = button(card, "Buy", "WEAR", 10, CH - 46, CW - 20, 36, "light", function()
					Net.send("Settings", "equip", { kind = it.kind, key = it.key })
				end)
			else
				buy = priceButton(card, "Buy", 10, CH - 46, CW - 20, 36, { robux = prod.robux }, "gold", function()
					waitFor(60, function(np)
						return Locker.owns(np, it.key)
					end, function()
						celebrate({ item = it, title = "YOURS FOREVER!" })
					end)
					Net.send("Buy", "robux", prod.key)
				end)
			end
			-- the shine: a bright bar that sweeps across now and then
			local shine = Theme.new("Frame", {
				Name = "Shine",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(-0.3, 0, 0.5, 0),
				Size = UDim2.new(0, 34, 1.6, 0),
				Rotation = 20,
				BackgroundColor3 = C.white,
				BackgroundTransparency = 0.75,
				BorderSizePixel = 0,
				ZIndex = 5,
				Parent = card,
			})
			shine:SetAttribute("Layer", true) -- (a light over the card on purpose)
			local phase = i * 0.37
			animate(card, function(t)
				hue.Rotation = (t * 90 + i * 25) % 360
				local s = ((t + phase) % 3.2) / 0.9
				shine.Position = UDim2.new(-0.3 + 1.6 * math.min(s, 1), 0, 0.5, 0)
				shine.Visible = s < 1
				emoji.Position = UDim2.new(0.78, 0, 0.3, math.sin(t * 3 + phase) * 5)
				emoji.Rotation = math.sin(t * 2 + phase) * 10
			end)
			refs.premiumCards[it.key] = { card = card, buy = buy, owned = owned }
		end
	end
	return y + CH + 22
end

-- mm:ss (or h:mm:ss) for the deal's countdown
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end
PanelController.clock = clock

-- The day's deal (Shop.DEAL, the "Deal" attribute the server sets): one Robux-only item 70% off for its hour, the
-- countdown ticking. Nothing while there's no deal on.
local function dealCard(body, y)
	local key = player:GetAttribute("Deal")
	local ends = tonumber(player:GetAttribute("DealEnds"))
	local d = type(key) == "string" and Shop.products[key]
	local it = d and Cosmetics.get(d.cosmetic)
	if not (d and it and ends) then
		return y
	end
	local RED = Color3.fromRGB(230, 40, 60)
	local card = frame(body, "Deal", 0, y, W, 132, Color3.fromRGB(30, 18, 30), RED)
	card.ClipsDescendants = true
	local ribbon = Theme.new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(W, 26),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Parent = card,
	})
	label(
		ribbon,
		"Words",
		`⚡ TODAY'S DEAL  ·  {math.floor(Shop.DEAL.off * 100 + 0.5)}% OFF ⚡`,
		10,
		3,
		W - 200,
		20,
		16,
		C.white,
		nil,
		Theme.Display
	)
	local timer = label(
		ribbon,
		"Timer",
		`ENDS IN {clock(ends - now())}`,
		W - 190,
		3,
		180,
		20,
		16,
		C.white,
		Enum.TextXAlignment.Right,
		Theme.Display
	)
	preview(card, it, 10, 34, 120, 90)
	label(card, "Name", it.name, 142, 34, W - 320, 26, 22, C.white, nil, Theme.Display)
	label(
		card,
		"Kind",
		(it.kind == "effect" and "KILL EFFECT" or Cosmetics.KIND_NAME[it.kind]) .. "  ·  yours forever",
		142,
		62,
		W - 320,
		16,
		12,
		Color3.fromRGB(220, 200, 220)
	)
	label(
		card,
		"Was",
		`was {Format.robux(d.was)}`,
		142,
		84,
		W - 320,
		18,
		15,
		Color3.fromRGB(255, 150, 160),
		nil,
		Theme.Display
	)
	local strike = Theme.new("Frame", {
		Name = "Strike",
		Position = UDim2.fromOffset(142, 93),
		Size = UDim2.fromOffset(110, 2),
		BackgroundColor3 = Color3.fromRGB(255, 150, 160),
		BorderSizePixel = 0,
		Parent = card,
	})
	strike:SetAttribute("Layer", true) -- (a line through the old price on purpose)
	local buy = priceButton(card, "BuyDeal", W - 170, 50, 160, 56, { robux = d.robux }, "gold", function()
		waitFor(60, function(np)
			return Locker.owns(np, it.key)
		end, function()
			celebrate({ item = it, title = "YOURS FOREVER!" })
		end)
		Net.send("Buy", "robux", d.key)
	end)
	refs.deal = buy
	animate(card, function(t)
		local left = ends - now()
		timer.Text = left > 0 and `ENDS IN {clock(left)}` or "DEAL OVER"
		local s = 1 + 0.04 * math.sin(t * 6)
		buy.Size = UDim2.fromOffset(160 * s, 56 * s)
	end)
	return y + 132 + 14
end

-- The TNT (a game pass, for good): at the top of the shop until it's yours, as on the hotbar
local function tntCard(body, y, team)
	if player:GetAttribute("OwnsTNT") == true then
		return y
	end
	local off = Shop.off(Shop.TNT)
	y = section(
		body,
		"TntLabel",
		"🧨 TNT: PERMANENT",
		y,
		off and `{off}% OFF  ·  was {Format.robux(Shop.TNT.was)}` or nil
	)
	local card = frame(body, "Tnt", 0, y, W, 104, GOLD_SOFT, GOLD)
	picture(card, 8, 8, 110, 88, function(box, w, h)
		local props = fill(w, h)
		props.Parent = box
		Icons.weapon("tnt", team, props)
	end)
	label(
		card,
		"Name",
		off and `{Shop.TNT.name}  ·  PERMANENT  ·  {off}% OFF` or `{Shop.TNT.name}  ·  PERMANENT`,
		128,
		10,
		W - 290,
		24,
		20,
		C.ink,
		nil,
		Theme.Display
	)
	label(card, "Desc", Shop.TNT.desc, 128, 38, W - 290, 34, 13, C.ink)
	label(card, "Note", "Buy once, keep it forever. No more locked slot.", 128, 76, W - 290, 16, 12, C.muted)
	priceButton(card, "BuyTnt", W - 154, 30, 144, 44, { robux = Shop.TNT.robux }, "gold", function()
		Net.send("Buy", "robux", "tnt")
	end)
	return y + 104 + 14
end

local function shopTab(body)
	local p = profile()
	local t = now()
	local team = Store.team() or "red"
	local day = Shop.dayOf(t)
	-- a welcome
	local hi = frame(body, "Welcome", 0, 0, W, 54, GOLD_SOFT, GOLD)
	label(hi, "Hello", "Pick something fun!", 12, 6, 330, 26, 22, C.ink, nil, Theme.Display)
	label(hi, "Line", "Everything here is just for looks: no one buys a better bow.", 12, 32, 360, 16, 12, C.muted)
	label(
		hi,
		"Fresh",
		`NEW ITEMS IN {span((day + 1) * 86400 - t)}`,
		W - 190,
		17,
		178,
		20,
		13,
		C.ink,
		Enum.TextXAlignment.Right,
		Theme.Display
	)
	local y = 64
	-- the day's deal and the TNT: first thing they see
	y = dealCard(body, y)
	y = tntCard(body, y, team)
	-- PREMIUM: the Robux-only ones, always here, the loudest thing in the shop
	y = premiumRow(body, y)
	-- FEATURED: this week's bundle, 30% off
	local week = Shop.weekOf(t)
	local bundle = Shop.weekly(week)
	local weekEnds = ((week + 1) * 7 - 3) * 86400
	local fc = frame(body, "Featured", 0, y, W, 150, C.white, GOLD)
	local ribbon = Theme.new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(250, 24),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = fc,
	}, { Theme.corner(6) })
	label(ribbon, "Words", "FEATURED  ·  BEST VALUE", 10, 3, 230, 18, 14, C.ink, nil, Theme.Display)
	local all, worth = true, 0
	for i, key in bundle.keys do
		local it = Cosmetics.get(key)
		local px = 10 + (i - 1) * 102
		preview(fc, it, px, 30, 94, 80)
		label(fc, "BName" .. i, it.name, px, 114, 94, 16, 12, C.ink, Enum.TextXAlignment.Center, Theme.Display)
		label(fc, "BKind" .. i, Cosmetics.KIND_NAME[it.kind], px, 130, 94, 12, 10, C.muted, Enum.TextXAlignment.Center)
		all = all and Locker.owns(p, key)
		worth += Shop.price(it)
	end
	local rx = 322
	label(fc, "BTitle", "THIS WEEK'S BUNDLE", rx, 30, W - rx - 10, 22, 18, C.ink, nil, Theme.Display)
	label(
		fc,
		"BOff",
		`30% OFF  ·  ENDS IN {span(weekEnds - t)}`,
		rx,
		54,
		W - rx - 10,
		16,
		13,
		C.red,
		nil,
		Theme.Display
	)
	label(fc, "BWorth", `3 items worth {money(worth)} Shards on their own`, rx, 72, W - rx - 10, 14, 11, C.muted)
	if all then
		button(fc, "BuyBundle", "ALL YOURS!", rx, 94, W - rx - 10, 44, "grey")
	else
		priceButton(fc, "BuyBundle", rx, 94, W - rx - 10, 44, { shards = bundle.price }, "gold", function()
			confirmBuy(nil, bundle.price, bundle)
		end)
	end
	y += 150 + 14
	-- today's items
	refs.todayY = y
	y = section(body, "TodayLabel", "TODAY'S ITEMS", y, `NEW ONES IN {span((day + 1) * 86400 - t)}`)
	local cw = (W - 3 * 8) / 4
	for i, key in Shop.daily(day, player:GetAttribute("ShopRoll")) do
		itemCard(body, i, key, (i - 1) * (cw + 8), y, cw)
	end
	y += 200 + 14
	-- every item, any day: a section a kind, four to a row
	refs.allY = y
	local n = 100
	for _, kind in Cosmetics.KINDS do
		local keys = {}
		for _, it in Cosmetics.list do
			if it.source == "shop" and it.kind == kind then
				table.insert(keys, it.key)
			end
		end
		table.sort(keys, function(a, b)
			local ia, ib = Cosmetics.get(a), Cosmetics.get(b)
			if Shop.price(ia) ~= Shop.price(ib) then
				return Shop.price(ia) < Shop.price(ib)
			end
			return ia.name < ib.name
		end)
		if #keys > 0 then
			local name = Cosmetics.KIND_NAME[kind] or string.upper(kind)
			y = section(body, "All_" .. kind, `ALL {name}S`, y, `{#keys} TO GET`)
			for i, key in keys do
				n += 1
				local col, row = (i - 1) % 4, (i - 1) // 4
				itemCard(body, n, key, col * (cw + 8), y + row * (200 + 8), cw)
			end
			y += math.ceil(#keys / 4) * (200 + 8) + 6
		end
	end
	-- Shards
	refs.packsY = y
	y = section(body, "ShardsLabel", "GET SHARDS", y, "Spend them on anything in the shop")
	for i, pack in Shop.PACKS do
		local best = i == #Shop.PACKS
		local card =
			frame(body, "Pack" .. i, (i - 1) * (cw + 8), y, cw, 200, best and GOLD_SOFT or C.white, best and GOLD)
		if pack.tag then
			local tag = Theme.new("Frame", {
				Name = "Tag",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(cw, 22),
				BackgroundColor3 = best and GOLD or Theme.SHARD,
				BorderSizePixel = 0,
				Parent = card,
			}, { Theme.corner(6) })
			label(
				tag,
				"Words",
				best and pack.tag or `{pack.tag} EXTRA`,
				6,
				3,
				cw - 12,
				16,
				12,
				best and C.ink or C.white,
				Enum.TextXAlignment.Center,
				Theme.Display
			)
		end
		picture(card, 8, 28, cw - 16, 80, function(box, w, h)
			local props = fill(w, h)
			props.Parent = box
			Icons.shardPile(i, props)
		end)
		Theme.shards(card, pack.shards, {
			Name = "Amount",
			w = cw - 16,
			h = 26,
			Position = UDim2.fromOffset(8, 112),
		})
		label(card, "Name", pack.name, 8, 140, cw - 16, 14, 11, C.muted, Enum.TextXAlignment.Center)
		priceButton(card, "BuyPack", 8, 160, cw - 16, 34, { robux = pack.robux }, best and "gold" or "dark", function()
			local before = profile().shards or 0
			waitFor(60, function(np)
				return (np.shards or 0) >= before + pack.shards
			end, function()
				celebrate({ shards = pack.shards, size = i })
			end)
			Net.send("Buy", "robux", pack.key)
		end)
	end
	y += 200 + 14
	-- the season's pass, from here too
	local s = p.season or {}
	y = section(body, "PassLabel", "THE TURF PASS", y, `SEASON ENDS IN {span(Season.at(t).endsAt - t)}`)
	local half = (W - 8) / 2
	local pc = frame(body, "PassCard", 0, y, half, 104, s.premium and C.white or GOLD_SOFT, GOLD)
	picture(pc, 8, 8, 96, 88, function(box, w, h)
		local props = fill(w, h)
		props.Parent = box
		Icons.pass(props)
	end)
	label(pc, "Name", "TURF PASS", 112, 8, half - 120, 22, 18, C.ink, nil, Theme.Display)
	label(pc, "Desc", "A gold reward on every tier this season", 112, 30, half - 120, 28, 12, C.muted)
	if s.premium then
		button(pc, "SeePass", "SEE MY REWARDS", 112, 62, half - 120, 34, "light", function()
			PanelController.open("pass")
		end)
	else
		priceButton(pc, "GetPass", 112, 62, half - 120, 34, { robux = Shop.PASS.robux }, "gold", function()
			PanelController.buyPass()
		end)
	end
	local tc = frame(body, "TierCard", half + 8, y, half, 104)
	picture(tc, 8, 8, 96, 88, function(box, w, h)
		local props = fill(w, h)
		props.Parent = box
		Icons.tierUp(props)
	end)
	label(tc, "Name", "+1 TIER", 112, 8, half - 120, 22, 18, C.ink, nil, Theme.Display)
	label(tc, "Desc", "Skip ahead one tier now, as often as you like", 112, 30, half - 120, 28, 12, C.muted)
	priceButton(tc, "AddTier", 112, 62, half - 120, 34, { robux = Shop.TIER.robux }, "dark", function()
		PanelController.buyTier()
	end)
	y += 104 + 14
	-- once
	local oneTime = not p.starter or Shop.CLUB.subscriptionId ~= nil
	if oneTime then
		y = section(body, "OnceLabel", "ONE TIME ONLY", y)
		local x = 0
		local wide = (p.starter or not Shop.CLUB.subscriptionId) and W or half
		if not p.starter then
			local card = frame(body, "Starter", x, y, wide, 104, GOLD_SOFT, GOLD)
			picture(card, 8, 8, 110, 88, function(box, w, h)
				local props = fill(w, h)
				props.Parent = box
				Icons.gift(team, props)
			end)
			local off = Shop.off(Shop.STARTER)
			label(
				card,
				"Name",
				off and `{Shop.STARTER.name}  ·  {off}% OFF (was {Format.robux(Shop.STARTER.was)})`
					or Shop.STARTER.name,
				128,
				10,
				wide - 290,
				24,
				20,
				C.ink,
				nil,
				Theme.Display
			)
			label(card, "Desc", Shop.STARTER.desc:gsub("◆", "Shards"), 128, 38, wide - 290, 18, 13, C.ink)
			label(card, "Note", "The best deal in the shop. Only once!", 128, 60, wide - 290, 16, 12, C.muted)
			priceButton(card, "BuyStarter", wide - 154, 30, 144, 44, { robux = Shop.STARTER.robux }, "gold", function()
				waitFor(60, function(np)
					return np.starter == true
				end, function()
					celebrate({ item = Cosmetics.get(Shop.STARTER.cosmetic), title = "STARTER PACK!" })
				end)
				Net.send("Buy", "robux", "starter")
			end)
			x += wide + 8
		end
		if Shop.CLUB.subscriptionId then
			local card = frame(body, "Club", x, y, half, 104)
			label(card, "Name", Shop.CLUB.name, 10, 10, half - 130, 22, 18, C.ink, nil, Theme.Display)
			label(card, "Desc", Shop.CLUB.desc:gsub("◆", "Shards"), 10, 36, half - 130, 30, 12, C.muted)
			button(card, "JoinClub", "JOIN", half - 110, 30, 100, 44, true, function()
				pcall(function()
					game:GetService("MarketplaceService"):PromptSubscriptionPurchase(player, Shop.CLUB.subscriptionId)
				end)
			end)
		end
		y += 104 + 14
	end
	return y
end

-- The Turf Pass ---------------------------------------------------------------------------------------------------
local COL = 92 -- a tier's column on the track
local function passReward(cell, r, w)
	if r.kind == "shards" then
		picture(cell, 4, 4, w - 8, 32, function(box, bw, bh)
			Theme.shards(box, r.amount, { Name = "Amount", w = bw, h = bh - 10, Position = UDim2.fromOffset(0, 5) })
		end)
	else
		preview(cell, Cosmetics.get(r.key), 4, 4, w - 8, 32)
	end
end

function PanelController.buyPass()
	waitFor(60, function(np)
		return (np.season or {}).premium == true
	end, function()
		celebrate({ pass = true })
	end)
	Net.send("Buy", "robux", "pass")
end

function PanelController.buyTier()
	local before = (profile().season or {}).tier or 0
	waitFor(60, function(np)
		return ((np.season or {}).tier or 0) > before
	end, function()
		celebrate({ tier = before + 1 })
	end)
	Net.send("Buy", "robux", "tier")
end

-- The pass fits the body without scrolling down: what it is (0-80), where you are (86-122), the pass and +1 TIER
-- (128-168), the track (176-352: YOU ARE HERE, the tier, the FREE row, the gold PASS row)
local function passTab(body)
	local p = profile()
	local s = p.season or { n = Season.at(now()).n, xp = 0, claimed = {} }
	local info = Season.at(now())
	local tier = Season.tierOf(s.xp)
	local into = (s.xp or 0) - tier * Season.XP_PER_TIER
	local top = tier >= Season.TIERS
	-- what it is, in plain words
	local intro = frame(body, "Intro", 0, 0, W, 80, GOLD_SOFT, GOLD)
	picture(intro, 8, 8, 76, 64, function(box, w, h)
		local props = fill(w, h)
		props.Parent = box
		Icons.pass(props)
	end)
	label(intro, "Season", s.name or Season.name(s.n), 94, 6, W - 250, 20, 17, C.ink, nil, Theme.Display)
	label(
		intro,
		"Ends",
		`{span(info.endsAt - now())} LEFT`,
		W - 146,
		6,
		136,
		20,
		14,
		C.red,
		Enum.TextXAlignment.Right,
		Theme.Display
	)
	label(
		intro,
		"How",
		"Play matches to earn XP. Every tier gives a reward. The Turf Pass unlocks the gold rewards too.",
		94,
		28,
		W - 104,
		30,
		13,
		C.ink
	)
	label(
		intro,
		"Xp",
		`A match: {Season.xpFor({ seconds = 60 })} XP, more for winning, knockouts, assists and building. First match of the day: +{Season.DAILY_BONUS} XP. {Season.XP_PER_TIER} XP = 1 tier.`,
		94,
		58,
		W - 104,
		16,
		11,
		C.muted
	)
	-- where you are
	local you = Theme.new("Frame", {
		Name = "You",
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.fromOffset(W, 36),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local badge = frame(you, "Badge", 0, 0, 60, 36, C.ink)
	label(badge, "Word", "TIER", 2, 2, 56, 10, 9, C.white, Enum.TextXAlignment.Center, Theme.Display)
	label(badge, "Tier", tostring(tier), 2, 12, 56, 22, 20, C.white, Enum.TextXAlignment.Center, Theme.Display)
	local _, bfill = Theme.bar({
		Name = "Progress",
		Position = UDim2.fromOffset(70, 3),
		Size = UDim2.fromOffset(W - 70, 14),
		BackgroundColor3 = LIGHT,
		Parent = you,
	}, GOLD)
	bfill.Size = UDim2.fromScale(top and 1 or into / Season.XP_PER_TIER, 1)
	refs.xpText = label(
		you,
		"XpText",
		top and `ALL {Season.TIERS} TIERS DONE!` or `{money(into)} / {money(Season.XP_PER_TIER)} XP  to tier {tier + 1}`,
		70,
		20,
		W - 70,
		16,
		13,
		C.ink,
		nil,
		Theme.Display
	)
	-- the pass and +1 tier
	if s.premium then
		button(body, "GetPass", "YOU HAVE THE PASS!", 0, 128, 290, 40, "green")
	else
		button(
			body,
			"GetPass",
			`GET THE TURF PASS   {Format.robux(Shop.PASS.robux)}`,
			0,
			128,
			290,
			40,
			"gold",
			function()
				PanelController.buyPass()
			end
		)
	end
	local at = button(body, "AddTier", "", 298, 128, W - 298, 40, top and "grey" or "dark", function()
		if not top then
			PanelController.buyTier()
		end
	end)
	at.Label.Text = `+1 TIER   {Format.robux(Shop.TIER.robux)}`
	at.Label.Position = UDim2.fromOffset(4, 2)
	at.Label.Size = UDim2.new(1, -8, 0, 20)
	text(at, {
		Name = "Sub",
		Text = top and "You're at the top tier" or "Skip ahead one tier now",
		Position = UDim2.fromOffset(4, 22),
		Size = UDim2.new(1, -8, 0, 14),
		fit = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = top and C.muted or C.grey,
	})
	-- the track: the rows' names at the left, the tiers to scroll across
	local ty = 176
	local rows = Theme.new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, ty),
		Size = UDim2.fromOffset(54, 170),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local ft = frame(rows, "FreeTag", 0, 38, 54, 62, C.white)
	label(ft, "Words", "FREE", 2, 14, 50, 18, 14, C.ink, Enum.TextXAlignment.Center, Theme.Display)
	label(ft, "Sub", "everyone", 2, 34, 50, 12, 10, C.muted, Enum.TextXAlignment.Center)
	local pt = frame(rows, "PassTag", 0, 104, 54, 62, GOLD)
	label(pt, "Words", "PASS", 2, 14, 50, 18, 14, C.ink, Enum.TextXAlignment.Center, Theme.Display)
	label(pt, "Sub", s.premium and "yours!" or "gold", 2, 34, 50, 12, 10, C.ink, Enum.TextXAlignment.Center)
	local track = Theme.new("ScrollingFrame", {
		Name = "Track",
		Position = UDim2.fromOffset(60, ty),
		Size = UDim2.fromOffset(W - 60, 176),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromOffset((Season.TIERS + 1) * COL, 0),
		Parent = body,
	})
	refs.track = track
	local cw = COL - 14 -- (a reward's cell)
	for t = 0, Season.TIERS do
		local here = t == tier
		local col = Theme.new("Frame", {
			Name = "Tier" .. t,
			Position = UDim2.fromOffset(t * COL, 0),
			Size = UDim2.fromOffset(COL - 6, 168),
			BackgroundColor3 = here and GOLD_SOFT or C.white,
			BackgroundTransparency = here and 0 or 1,
			BorderSizePixel = 0,
			Parent = track,
		}, { Theme.corner(6) })
		if here then
			Theme.stroke(3, GOLD).Parent = col
			local m = Theme.new("Frame", {
				Name = "Marker",
				Position = UDim2.fromOffset(3, 2),
				Size = UDim2.fromOffset(COL - 12, 16),
				BackgroundColor3 = C.red,
				BorderSizePixel = 0,
				Parent = col,
			}, { Theme.corner("round") })
			label(
				m,
				"Words",
				"YOU ARE HERE",
				4,
				2,
				COL - 20,
				12,
				10,
				C.white,
				Enum.TextXAlignment.Center,
				Theme.Display
			)
			refs.here = m
		end
		label(
			col,
			"Num",
			t == 0 and "START" or `TIER {t}`,
			2,
			19,
			COL - 10,
			16,
			13,
			t <= tier and C.ink or C.muted,
			Enum.TextXAlignment.Center,
			Theme.Display
		)
		if t == 0 then
			local go = frame(col, "Go", 4, 38, cw, 128, C.white)
			label(go, "Words", "PLAY A MATCH", 4, 24, cw - 8, 34, 13, C.ink, Enum.TextXAlignment.Center, Theme.Display)
			label(go, "Sub", "to earn your first XP", 4, 64, cw - 8, 30, 11, C.muted, Enum.TextXAlignment.Center)
		else
			for _, row in { { "f", 38 }, { "p", 104 } } do
				local key, ry = row[1], row[2]
				local r = Season.reward(s.n, t, key)
				local claimed = (s.claimed or {})[tostring(t) .. key]
				local reached = t <= tier
				local needPass = key == "p" and not s.premium
				local ready = r and reached and not claimed and not needPass
				local bg = key == "p" and (s.premium and GOLD_SOFT or LIGHT) or (r and C.white or LIGHT)
				local cell = frame(col, key == "f" and "Free" or "Prem", 4, ry, cw, 62, bg, ready and GOLD)
				if ready and not Theme.reducedMotion() then
					-- (claimable: it glows)
					Theme.tween(
						cell:FindFirstChildOfClass("UIStroke"),
						0.7,
						{ Transparency = 0.6 },
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)
				end
				if not r then
					label(cell, "Empty", "—", 4, 16, cw - 8, 28, 16, C.muted, Enum.TextXAlignment.Center)
				else
					passReward(cell, r, cw)
					if claimed then
						tick(cell, cw / 2, 48, 16)
					elseif ready then
						button(cell, "Claim", "CLAIM", 4, 38, cw - 8, 20, "gold", function()
							Net.send("Claim", t, key)
						end)
					elseif needPass then
						padlock(cell, 13, 48, 13)
						button(cell, "GetPass", "GET PASS", 24, 39, cw - 28, 18, "light", function()
							PanelController.buyPass()
						end)
					else
						padlock(cell, 13, 48, 13, C.muted)
						label(cell, "Locked", `TIER {t}`, 24, 40, cw - 28, 16, 11, C.muted)
					end
				end
			end
		end
	end
	-- (start the track a column before where you are)
	track.CanvasPosition = Vector2.new(math.max(0, (tier - 1) * COL), 0)
	return ty + 176
end

local function lockerTab(body)
	local p = profile()
	local cw = (W - 4 * 6) / 5
	for i, k in Cosmetics.KINDS do
		button(body, "Chip_" .. k, Cosmetics.KIND_NAME[k], (i - 1) * (cw + 6), 0, cw, 30, k == lockerKind, function()
			lockerKind = k
			PanelController.refresh()
		end)
	end
	-- every item of the kind: the ones you have first, then the rest with how to get them
	local items = {}
	local function addAll(list)
		for _, it in list do
			if it.kind == lockerKind then
				table.insert(items, it)
			end
		end
	end
	addAll(Cosmetics.list)
	local ladder = {}
	for _, st in Ladder.steps do
		table.insert(ladder, Cosmetics.get(st.key))
	end
	for _, e in { "extra_thanks", "extra_buddy" } do
		table.insert(ladder, Cosmetics.get(e))
	end
	for key in p.owned or {} do
		local it = Cosmetics.get(key)
		if it and it.source == "pass" then
			table.insert(ladder, it)
		end
	end
	addAll(ladder)
	table.sort(items, function(a, b)
		local oa, ob = Locker.owns(p, a.key), Locker.owns(p, b.key)
		if oa ~= ob then
			return oa
		end
		return (a.win or 0) < (b.win or 0)
	end)
	table.insert(items, 1, { key = false, kind = lockerKind, name = "None" })
	local gw = (W - 3 * 8) / 4
	local y = 40
	for i, it in items do
		local col = (i - 1) % 4
		local x = col * (gw + 8)
		local owned = it.key == false or Locker.owns(p, it.key)
		local worn = it.key == false and (p.equipped or {})[lockerKind] == nil
			or (p.equipped or {})[lockerKind] == it.key
		local card = Theme.new("TextButton", {
			Name = "Item" .. i,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(gw, 132),
			BackgroundColor3 = worn and C.ink or (owned and C.white or LIGHT),
			Text = "",
			AutoButtonColor = owned,
			Parent = body,
		}, { Theme.corner(6), Theme.stroke(worn and 3 or 2, worn and GOLD or C.ink) })
		card:SetAttribute("Key", it.key or "")
		if it.key and it.key == spotlight then
			if worn then
				spotlight = nil -- (worn: the point's made)
			else
				-- (the free gift: a pulsing gold ring and a hand on it, and the panel scrolls to it)
				local ring = Theme.new("Frame", {
					Name = "Spotlight",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 10, 1, 10),
					BackgroundTransparency = 1,
					ZIndex = 6,
					Parent = card,
				}, { Theme.corner(9), Theme.stroke(4, GOLD) })
				ring:SetAttribute("Layer", true)
				local hand = Theme.new("TextLabel", {
					Name = "Hand",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.fromOffset(gw, 26),
					BackgroundTransparency = 1,
					Text = "👆 TAP TO WEAR",
					Font = Theme.Display,
					TextSize = 15,
					TextColor3 = GOLD,
					ZIndex = 7,
					Parent = card,
				}, { Theme.textStroke(2, C.ink) })
				hand:SetAttribute("Layer", true)
				animate(ring, function(t)
					local k = 0.5 + 0.5 * math.sin(t * 6)
					ring.Size = UDim2.new(1, 8 + k * 8, 1, 8 + k * 8)
					hand.Position = UDim2.new(0.5, 0, 1, -6 + k * 6)
				end)
				refs.spotY = y
			end
		end
		if it.key then
			local pic = preview(card, it, 6, 6, gw - 12, 74)
			if not owned then
				-- (not yours yet: the picture greyed under a lock)
				Theme.new("Frame", {
					Name = "Veil",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = C.white,
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					ZIndex = 2,
					Parent = pic,
				})
				padlock(pic, (gw - 12) / 2, 37, 22).ZIndex = 3
			end
		else
			picture(card, 6, 6, gw - 12, 74, function(box, w, h)
				text(box, {
					Name = "Words",
					Text = "NOTHING",
					Size = UDim2.fromOffset(w, h),
					fit = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = C.muted,
					Font = Theme.Display,
				})
			end)
		end
		label(card, "Name", it.name, 8, 84, gw - 16, 20, 14, worn and C.white or C.ink, nil, Theme.Display)
		local line = worn and "WEARING" or (owned and "TAP TO WEAR" or ("🔒 " .. Locker.how(it)))
		label(card, "Line", line, 8, 106, gw - 16, 20, 11, worn and GOLD or C.muted)
		if owned then
			Theme.pressable(card)
			card.Activated:Connect(function()
				Net.send("Settings", "equip", { kind = lockerKind, key = it.key or nil })
			end)
		elseif it.source == "shop" then
			-- (any shop item, any day: a tap buys it with Shards)
			Theme.pressable(card)
			card.Activated:Connect(function()
				confirmBuy(it, Shop.price(it))
			end)
		elseif it.source == "robux" then
			-- (Robux only: gold-edged, the price on it, a tap opens the purchase)
			card.BackgroundColor3 = GOLD_SOFT
			local edge = card:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Color = GOLD
			end
			Theme.pressable(card)
			card.Activated:Connect(function()
				waitFor(60, function(np)
					return Locker.owns(np, it.key)
				end, function()
					celebrate({ item = it, title = "YOURS FOREVER!" })
				end)
				Net.send("Buy", "robux", it.key)
			end)
		end
		if col == 3 then
			y += 140
		end
	end
	if #items % 4 ~= 0 then
		y += 140
	end
	return y
end

local function goalsTab(body)
	local p = profile()
	local vip = p.vip == true
	local vc = frame(body, "Vip", 0, 0, W, 92, vip and C.ink or C.white)
	local inkOrWhite = vip and C.white or C.ink
	label(vc, "Title", vip and "YOU'RE VIP" or "VIP", 10, 8, W - 20, 22, 18, inkOrWhite)
	label(
		vc,
		"Line",
		"Earned, never bought. " .. Achievements.VIP.perks .. ".",
		10,
		32,
		W - 20,
		16,
		12,
		vip and C.white or C.muted
	)
	local vp = Achievements.vipProgress(p)
	label(
		vc,
		"Progress",
		vip and "Kept for good." or `WINS {vp.wins} / {vp.needWins}   ·   MVPS {vp.mvps} / {vp.needMvps}`,
		10,
		52,
		W - 20,
		16,
		12,
		inkOrWhite
	)
	local _, vfill = Theme.bar({
		Name = "VipBar",
		Position = UDim2.fromOffset(10, 72),
		Size = UDim2.fromOffset(W - 20, 10),
		BackgroundColor3 = LIGHT,
		Parent = vc,
	}, vip and C.white or C.ink)
	vfill.Size = UDim2.fromScale(vip and 1 or (vp.wins / vp.needWins + vp.mvps / vp.needMvps) / 2, 1)
	local mc = frame(body, "Mvp", 0, 100, W, 60)
	local mvps = (p.stats or {}).mvps or 0
	label(mc, "Title", `MVP  ·  YOU'VE BEEN MVP {mvps} TIME{mvps == 1 and "" or "S"}`, 10, 8, W - 20, 20, 15)
	label(
		mc,
		"Line",
		"The match MVP wears the crown all next match. 10 MVPs: the MVP title. 25: the Spotlight kill effect.",
		10,
		32,
		W - 20,
		18,
		12,
		C.muted
	)
	local y = 170
	for i, g in Achievements.goals do
		local done = Achievements.done(p, g)
		local it = Cosmetics.get(g.reward)
		local row = frame(body, "Goal" .. i, 0, y, W, 56, done and C.white or LIGHT)
		label(row, "Name", (done and "DONE · " or "") .. g.name, 10, 6, 330, 20, 15)
		label(
			row,
			"Reward",
			`{it.name} · {Cosmetics.KIND_NAME[it.kind]}`,
			350,
			6,
			W - 360,
			20,
			12,
			C.muted,
			Enum.TextXAlignment.Right
		)
		label(row, "Desc", g.desc, 10, 28, 330, 14, 12, C.muted)
		local have = Achievements.progress(p, g)
		label(
			row,
			"Count",
			`{money(have)} / {money(g.goal)}`,
			350,
			28,
			W - 360,
			14,
			12,
			C.ink,
			Enum.TextXAlignment.Right
		)
		local _, gfill = Theme.bar({
			Name = "Bar",
			Position = UDim2.fromOffset(10, 46),
			Size = UDim2.fromOffset(W - 20, 6),
			BackgroundColor3 = C.white,
			Parent = row,
		}, C.ink)
		gfill.Size = UDim2.fromScale(have / g.goal, 1)
		y += 62
	end
	-- the first-game guide, again (TutorialService)
	local tr = frame(body, "Tutorial", 0, y, W, 48)
	label(tr, "Title", "HOW TO PLAY", 10, 6, 330, 20, 15)
	label(tr, "Line", "Watch the first-game guide again.", 10, 28, 330, 14, 12, C.muted)
	button(tr, "Replay", "REPLAY", W - 130, 9, 120, 30, true, function()
		Net.send("Tutorial", "replay")
		PanelController.close()
	end)
	return y + 54
end

-- PLAYERS: everyone on the server, by team (who's VIP, who's in your party), with INVITE to party up
local function playersTab(body)
	local Constants = require(ReplicatedStorage.Shared.Constants)
	local mine = player:GetAttribute("Party")
	local everyone = {}
	for _, p in Players:GetPlayers() do
		-- (an unseen admin isn't listed, except to themselves)
		if p == player or not p:GetAttribute("Spectating") then
			table.insert(everyone, p)
		end
	end
	local function team(p)
		local c = p.Character
		return p:GetAttribute("Team") or (c and c:GetAttribute("Team"))
	end
	local count = { red = 0, blue = 0 }
	for _, p in everyone do
		local t = team(p)
		if count[t] then
			count[t] += 1
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	local nBots = bots and #bots:GetChildren() or 0
	label(
		body,
		"Count",
		`{#everyone} ONLINE   ·   RED {count.red}   ·   BLUE {count.blue}{nBots > 0 and `   ·   🤖 {nBots} BOT{nBots == 1 and "" or "S"}` or ""}`,
		0,
		0,
		W,
		22,
		15
	)
	table.sort(everyone, function(a, b)
		local ta, tb = team(a) or "z", team(b) or "z"
		if ta ~= tb then
			return ta < tb
		end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	local y = 30
	for i, p in everyone do
		local t = team(p)
		local me = p == player
		local row = frame(body, "Player" .. i, 0, y, W, 40, me and C.ink or C.white)
		Theme.new("Frame", {
			Name = "Team",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = Constants.TEAM_COLOR[t or ""] or C.grey,
			BorderSizePixel = 0,
			Parent = row,
		}, { Theme.corner(4) })
		local tags = {}
		if me then
			table.insert(tags, "YOU")
		end
		if p:GetAttribute("VIP") then
			table.insert(tags, "⭐ VIP")
		end
		if mine and p:GetAttribute("Party") == mine and not me then
			table.insert(tags, "👥 PARTY")
		end
		local ink = me and C.white or C.ink
		label(row, "Name", `{p.DisplayName}  @{p.Name}`, 18, 4, W - 150, 18, 14, ink)
		label(
			row,
			"Line",
			`{t and Constants.TEAM_NAME[t] or "NO TEAM"}{#tags > 0 and ("  ·  " .. table.concat(tags, "  ·  ")) or ""}`,
			18,
			22,
			W - 150,
			14,
			11,
			me and C.white or C.muted
		)
		if not me and not (mine and p:GetAttribute("Party") == mine) then
			button(row, "Invite", "INVITE", W - 104, 6, 94, 28, true, function()
				Net.send("Party", "invite", p.UserId)
				PanelController.status(`Asked {p.DisplayName} to party up.`, "good")
			end)
		end
		y += 46
	end
	return y
end

local BUILD = {
	players = playersTab,
	shop = shopTab,
	pass = passTab,
	locker = lockerTab,
	goals = goalsTab,
}

-- The layer over the body: dialogs and the tour ------------------------------------------------------------------
local function clearLayer()
	local o = refs.overlay
	for _, c in o:GetChildren() do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
	refs.confirm, refs.celebrate, refs.tour = nil, nil, nil
	if refs.tourRing then
		refs.tourRing.Visible = false
	end
end

function PanelController.closeDialog()
	clearLayer()
	refs.overlay.Visible = false
end

-- A dialog card in the middle of the layer: a coloured head band with its title, the rest white
local function dialog(name, w, h, title, band, ink)
	clearLayer()
	local o = refs.overlay
	o.Visible = true
	o.BackgroundTransparency = 0.45
	local card = Theme.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Active = true,
		Parent = o,
	}, { Theme.corner(10), Theme.stroke(3, C.ink) })
	local head = Theme.new("Frame", {
		Name = "Head",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(w, 40),
		BackgroundColor3 = band or C.ink,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(10) })
	label(head, "Title", title, 12, 6, w - 24, 28, 22, ink or C.white, Enum.TextXAlignment.Center, Theme.Display)
	Theme.pop(card)
	return card
end

-- "Buy Neon Trail for 350?" YES / NO (or, for the bundle, its three pictures). Not enough Shards: how many more.
confirmBuy = function(it, price, bundle)
	local p = profile()
	local have = p.shards or 0
	if have < price then
		notEnough(price - have)
		return
	end
	local card = dialog("Confirm", 380, 270, "BUY IT?")
	refs.confirm = card
	if bundle then
		for i, key in bundle.keys do
			preview(card, Cosmetics.get(key), 16 + (i - 1) * 118, 50, 112, 84)
		end
	else
		preview(card, it, 120, 50, 140, 84)
	end
	label(
		card,
		"Question",
		bundle and "Buy this week's bundle for" or `Buy {it.name} for`,
		16,
		142,
		348,
		22,
		17,
		C.ink,
		Enum.TextXAlignment.Center,
		Theme.Display
	)
	Theme.shards(card, price, { Name = "Price", w = 348, h = 30, Position = UDim2.fromOffset(16, 166) })
	label(
		card,
		"Left",
		`You'll have {money(have - price)} Shards left.`,
		16,
		198,
		348,
		16,
		12,
		C.muted,
		Enum.TextXAlignment.Center
	)
	button(card, "No", "NO", 16, 222, 120, 38, "light", PanelController.closeDialog)
	button(card, "Yes", "YES, BUY IT!", 146, 222, 218, 38, "green", function()
		PanelController.closeDialog()
		waitFor(10, function(np)
			for _, k in bundle and bundle.keys or { it.key } do
				if not Locker.owns(np, k) then
					return false
				end
			end
			return true
		end, function()
			celebrate(bundle and { bundle = bundle } or { item = it })
		end)
		if bundle then
			Net.send("Buy", "bundle")
		else
			Net.send("Buy", "item", it.key)
		end
	end)
end

notEnough = function(need)
	local card = dialog("NotEnough", 380, 250, "ALMOST!", GOLD, C.ink)
	refs.confirm = card
	picture(card, 130, 50, 120, 84, function(box, w, h)
		local props = fill(w, h)
		props.Parent = box
		Icons.shardPile(2, props)
	end)
	label(
		card,
		"Question",
		`You need {money(need)} more Shards: get some?`,
		16,
		142,
		348,
		24,
		17,
		C.ink,
		Enum.TextXAlignment.Center,
		Theme.Display
	)
	label(
		card,
		"Earn",
		"Or play a few matches: every match pays Shards, and a win pays more.",
		16,
		168,
		348,
		28,
		12,
		C.muted,
		Enum.TextXAlignment.Center
	)
	button(card, "No", "NOT NOW", 16, 202, 120, 38, "light", PanelController.closeDialog)
	button(card, "GetShards", "GET SHARDS", 146, 202, 218, 38, "gold", function()
		PanelController.closeDialog()
		showPacks()
	end)
end

-- Straight to the Shard packs, with a little flash on them
showPacks = function()
	if current ~= "shop" or not PanelController.isOpen() then
		PanelController.open("shop")
	end
	if refs.packsY then
		refs.body.CanvasPosition = Vector2.new(0, refs.packsY - 6)
	end
	for i = 1, #Shop.PACKS do
		local card = refs.body:FindFirstChild("Pack" .. i)
		local edge = card and card:FindFirstChildOfClass("UIStroke")
		if edge then
			local was = edge.Color
			edge.Color = C.red
			task.delay(0.8, function()
				if edge.Parent then
					edge.Color = was
				end
			end)
		end
	end
end
PanelController.showPacks = showPacks

-- Confetti: little bits flying out from (x, y) and fading (a picture: they sit on each other)
local CONFETTI = { C.red, C.blue, GOLD, Theme.SHARD, C.ink }
local function confetti(parent, x, y)
	local box = Theme.new("Frame", {
		Name = "Confetti",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	box:SetAttribute("Art", true)
	box:SetAttribute("Layer", true)
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2 + (i % 3) * 0.3
		local d = 70 + (i % 5) * 26
		local bit = Theme.new("Frame", {
			Name = "Bit" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(i % 2 == 0 and 8 or 5, i % 2 == 0 and 5 or 10),
			Rotation = i * 37,
			BackgroundColor3 = CONFETTI[i % #CONFETTI + 1],
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = box,
		})
		local to = UDim2.fromOffset(x + math.cos(a) * d, y + math.sin(a) * d * 0.7)
		if Theme.reducedMotion() then
			bit.Position = to
		else
			Theme.tween(bit, 0.7, { Position = to, Rotation = i * 37 + 200 }, Enum.EasingStyle.Quart)
			task.delay(0.6, function()
				if bit.Parent then
					Theme.tween(bit, 0.5, { BackgroundTransparency = 1 })
				end
			end)
		end
	end
	-- (gone after its moment, also when it only snapped out with Reduced Motion)
	task.delay(1.2, function()
		box:Destroy()
	end)
	return box
end

-- A buy went through: a pop, confetti, NEW!, and EQUIP NOW when it isn't worn yet
celebrate = function(what)
	local p = profile()
	local title = what.title
		or (what.shards and `+{money(what.shards)} SHARDS!`)
		or (what.pass and "TURF PASS!")
		or (what.tier and `TIER {what.tier}!`)
		or "YOU GOT IT!"
	local card = dialog("Celebrate", 380, 270, title, GOLD, C.ink)
	refs.celebrate = card
	local function picBox(build)
		return picture(card, 110, 52, 160, 100, build)
	end
	local line, eq
	if what.item then
		preview(card, what.item, 110, 52, 160, 100)
		local worn = (p.equipped or {})[what.item.kind] == what.item.key
		line = `{what.item.name} is yours!`
		eq = not worn and { what.item } or nil
	elseif what.bundle then
		for i, key in what.bundle.keys do
			preview(card, Cosmetics.get(key), 16 + (i - 1) * 118, 52, 112, 100)
		end
		line = "The whole bundle is yours!"
		eq = {}
		for _, key in what.bundle.keys do
			table.insert(eq, Cosmetics.get(key))
		end
	elseif what.shards then
		picBox(function(box, w, h)
			local props = fill(w, h)
			props.Parent = box
			Icons.shardPile(what.size or 2, props)
		end)
		line = "Thank you! Spend them on anything in the shop."
	elseif what.pass then
		picBox(function(box, w, h)
			local props = fill(w, h)
			props.Parent = box
			Icons.pass(props)
		end)
		line = "The gold rewards are yours this season."
	else
		picBox(function(box, w, h)
			local props = fill(w, h)
			props.Parent = box
			Icons.tierUp(props)
		end)
		line = "Up a tier! Claim what's ready on the PASS tab."
	end
	label(card, "Line", line, 16, 160, 348, 26, 17, C.ink, Enum.TextXAlignment.Center, Theme.Display)
	label(
		card,
		"Sub",
		eq and "Wear it now, or any time from the LOCKER." or (what.item and "You're wearing it now." or ""),
		16,
		188,
		348,
		16,
		12,
		C.muted,
		Enum.TextXAlignment.Center
	)
	if eq then
		button(card, "Ok", "LATER", 16, 218, 120, 40, "light", PanelController.closeDialog)
		button(card, "Equip", "EQUIP NOW", 146, 218, 218, 40, "green", function()
			-- (all in one request: one of each kind, the last of a kind wins)
			local list = {}
			for _, it in eq do
				table.insert(list, { kind = it.kind, key = it.key })
			end
			Net.send("Settings", "equip", list)
			PanelController.closeDialog()
		end)
	elseif what.pass or what.tier then
		button(card, "Ok", "SEE MY REWARDS", 16, 218, 348, 40, "green", function()
			PanelController.closeDialog()
			PanelController.open("pass")
		end)
	else
		button(card, "Ok", "AWESOME!", 16, 218, 348, 40, "green", PanelController.closeDialog)
	end
	-- the sticker and the confetti
	local sticker = Theme.new("Frame", {
		Name = "New",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(318, 62),
		Size = UDim2.fromOffset(64, 30),
		Rotation = 12,
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = card,
	}, { Theme.corner(6), Theme.stroke(2, C.white) })
	sticker:SetAttribute("Art", true)
	sticker:SetAttribute("Layer", true) -- (stuck on top on purpose)
	text(sticker, {
		Name = "Words",
		Text = "NEW!",
		Size = UDim2.fromScale(1, 1),
		fit = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		Font = Theme.Display,
		ZIndex = 4,
	})
	confetti(card, 190, 100)
end
PanelController.celebrate = function(what)
	celebrate(what)
end

-- The shop's first-time tour: 3 steps, each a tip pointing at the thing with a ring round it -------------------
local TOUR = {
	{
		title = "YOUR SHARDS",
		line = "Shards buy everything in the shop. Every match pays some, a win pays more, or tap + for a pack.",
	},
	{
		title = "TODAY'S ITEMS",
		line = "Four new items every day. Tap a price to buy: we'll always ask before spending.",
	},
	{
		title = "THE TURF PASS",
		line = "Play matches to climb its tiers. Claim a reward on each one you reach.",
	},
}

local function finishTour()
	if refs.tour then
		Net.send("Settings", "shopTour", true)
	end
	toured = true
	PanelController.closeDialog()
	if refs.body then
		refs.body.CanvasPosition = Vector2.zero
	end
end
PanelController.finishTour = finishTour

local function tourStep(n)
	clearLayer()
	local o = refs.overlay
	o.Visible = true
	o.BackgroundTransparency = 0.6
	-- what it points at, in the panel's own pixels
	local tx, ty, tw, th
	if n == 1 then
		local s = refs.shards
		tx, ty, tw, th = s.Position.X.Offset, s.Position.Y.Offset, s.Size.X.Offset, s.Size.Y.Offset
	elseif n == 2 then
		refs.body.CanvasPosition = Vector2.new(0, (refs.todayY or 0) - 4)
		tx, ty, tw, th = 10, P.bodyY + 4, W, 226
	else
		local b = refs.tabs.pass
		tx, ty, tw, th = b.Position.X.Offset, b.Position.Y.Offset, b.Size.X.Offset, b.Size.Y.Offset
	end
	local ring = refs.tourRing
	ring.Visible = true
	ring.Position = UDim2.fromOffset(tx - 4, ty - 4)
	ring.Size = UDim2.fromOffset(tw + 8, th + 8)
	-- the tip: under the header for steps 1 and 3, under today's items for step 2 (in the layer's pixels)
	local tipW, tipH = 330, 128
	local tipX = math.clamp(tx + tw / 2 - tipW / 2, 10, P.w - tipW - 10)
	local tipY = n == 2 and (ty + th + 10 - P.head) or 10
	local tip = Theme.new("Frame", {
		Name = "Tour",
		Position = UDim2.fromOffset(tipX, tipY),
		Size = UDim2.fromOffset(tipW, tipH),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Active = true,
		Parent = o,
	}, { Theme.corner(10), Theme.stroke(3, GOLD) })
	tip:SetAttribute("Step", n)
	refs.tour = tip
	-- (the little point toward the thing)
	local point = Theme.new("Frame", {
		Name = "Point",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(math.clamp(tx + tw / 2 - tipX, 20, tipW - 20), 0),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = tip,
	})
	point:SetAttribute("Art", true)
	point:SetAttribute("Layer", true)
	label(tip, "Count", `{n} / {#TOUR}`, tipW - 60, 10, 48, 18, 13, GOLD, Enum.TextXAlignment.Right, Theme.Display)
	label(tip, "Title", TOUR[n].title, 14, 10, tipW - 80, 22, 18, C.white, nil, Theme.Display)
	label(tip, "Line", TOUR[n].line, 14, 36, tipW - 28, 40, 13, C.grey)
	button(tip, "Skip", "SKIP", 14, 84, 90, 32, "light", finishTour)
	button(tip, "Next", n == #TOUR and "GOT IT!" or "NEXT", tipW - 144, 84, 130, 32, "gold", function()
		if n >= #TOUR then
			finishTour()
		else
			tourStep(n + 1)
		end
	end)
	Theme.pop(tip)
end
PanelController.tourStep = tourStep

startTour = function()
	toured = true
	tourStep(1)
end

local function tourDue()
	local settings = profile().settings or {}
	return not toured and settings.shopTour ~= true
end

-- The panel -----------------------------------------------------------------------------------------------------
function PanelController.refresh()
	if not refs.panel then
		return
	end
	local p = profile()
	refs.shards.Price.Amount.Text = money(p.shards or 0)
	for _, t in TABS do
		local b = refs.tabs[t[1]]
		local on = t[1] == current
		b.BackgroundColor3 = on and C.ink or C.white
		b.Label.TextColor3 = on and C.white or C.ink
	end
	local body = refs.body
	local keep = current == refs.lastTab and body.CanvasPosition or Vector2.zero
	local trackAt = current == refs.lastTab and refs.track and refs.track.Parent and refs.track.CanvasPosition
	for _, c in body:GetChildren() do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
	refs.track, refs.here = nil, nil
	local h = BUILD[current](body)
	body.CanvasSize = UDim2.fromOffset(0, h)
	body.CanvasPosition = keep
	if trackAt and refs.track then
		refs.track.CanvasPosition = trackAt
	end
	refs.lastTab = current
end

function PanelController.status(s, kind)
	if refs.status then
		s = s and (s:gsub(" ?◆", " Shards")) or ""
		refs.status.Text = s
		-- (about Shards: the gem in front of the words, which are centred)
		local gem = refs.status:FindFirstChild("Gem") or Theme.gem(refs.status, 20, { Name = "Gem" })
		gem.Visible = string.find(s, "Shard") ~= nil
		local width = math.min(P.w - 20, (utf8.len(s) or #s) * 14 * 0.55)
		gem.Position = UDim2.fromOffset(math.max(0, (P.w - 20 - width) / 2 - 24), 3)
		refs.status.TextColor3 = kind == "bad" and C.red or (kind == "good" and C.ink or C.muted)
	end
end

local function build()
	local panel = Theme.card({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, P.top),
		Size = UDim2.fromOffset(P.w, P.h),
		BackgroundColor3 = C.white,
		Visible = false,
		Parent = gui,
	})
	refs.panel = panel
	refs.tabs = {}
	for i, t in TABS do
		refs.tabs[t[1]] = button(panel, "Tab_" .. t[1], t[2], 10 + (i - 1) * 74, 6, 70, 32, false, function()
			PanelController.open(t[1])
		end)
		-- (every tab's word the same size: the longest, PLAYERS, sets it)
		refs.tabs[t[1]].Label.UITextSizeConstraint.MaxTextSize = math.floor(13 * Theme.textFactor() + 0.5)
	end
	-- your Shards, big, and a + that goes to the packs
	local sh = Theme.new("TextButton", {
		Name = "Shards",
		Position = UDim2.fromOffset(384, 4),
		Size = UDim2.fromOffset(162, 36),
		BackgroundColor3 = C.white,
		Text = "",
		AutoButtonColor = true,
		Parent = panel,
	}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	Theme.shards(sh, 0, {
		Name = "Price",
		w = 112,
		h = 26,
		gem = 1,
		align = "left",
		Position = UDim2.fromOffset(8, 5),
	})
	local plus = Theme.new("TextButton", {
		Name = "AddShards",
		Position = UDim2.fromOffset(128, 4),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = GREEN,
		Text = "",
		AutoButtonColor = true,
		Parent = sh,
	}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	-- (the + drawn with two bars, like the close button's X)
	local glyph = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundTransparency = 1,
		Parent = plus,
	})
	glyph:SetAttribute("Art", true)
	for i, rot in { 0, 90 } do
		Theme.new("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 4),
			Rotation = rot,
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			Parent = glyph,
		}, { Theme.corner("round") })
	end
	Theme.pressable(plus)
	plus.Activated:Connect(showPacks)
	sh.Activated:Connect(showPacks)
	refs.shards = sh
	refs.addShards = plus
	refs.close = Theme.closeButton(panel, function()
		PanelController.close()
	end, { Position = UDim2.fromOffset(P.w - 46, 4), Size = UDim2.fromOffset(36, 36) })
	refs.close.Modal = true -- (frees the mouse from first person while the panel is up)
	refs.body = Theme.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(10, P.bodyY),
		Size = UDim2.fromOffset(P.w - 20, P.bodyH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	refs.status = text(panel, {
		Name = "Status",
		Text = "",
		Position = UDim2.fromOffset(10, P.footY),
		Size = UDim2.fromOffset(P.w - 20, P.footH),
		fit = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
	})
	-- the layer for dialogs and the tour, over everything under the header (it sits on the body on purpose)
	refs.overlay = Theme.new("Frame", {
		Name = "Overlay",
		Position = UDim2.fromOffset(0, P.head),
		Size = UDim2.fromOffset(P.w, P.h - P.head),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 10,
		Parent = panel,
	}, { Theme.corner(6) })
	refs.overlay:SetAttribute("Layer", true)
	refs.tourRing = Theme.new("Frame", {
		Name = "TourRing",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = panel,
	}, { Theme.corner(8), Theme.stroke(3, GOLD) })
	refs.tourRing:SetAttribute("Layer", true)
end

function PanelController.open(tab)
	if not refs.panel then
		return
	end
	local was = current
	current = tab or current
	Layout.claimPanel("panel", PanelController.close)
	local opening = not refs.panel.Visible
	refs.panel.Visible = true
	PanelController.status("")
	Layout.modal("panel", refs.panel)
	Layout.setPanel(true)
	if opening or was ~= current then
		-- (for the analytics: who opens the shop, on which tab, and how they got there)
		pcall(Net.send, "Analytics", "shop", { tab = current, opening = opening })
		if refs.tour then
			finishTour() -- (moved on mid-tour: it's been seen)
		else
			PanelController.closeDialog()
		end
	end
	PanelController.refresh()
	if current == "shop" and tourDue() then
		startTour()
	end
end

function PanelController.close()
	if refs.panel then
		if refs.tour then
			finishTour() -- (closed mid-tour: it's been seen)
		end
		PanelController.closeDialog()
		refs.panel.Visible = false
	end
	pending = nil
	Layout.setPanel(false)
end

-- Open the locker on this item's kind with the item pointed at (a free gift's EQUIP IT): a gold ring, a hand, and
-- scrolled to it. Returns the item's card (or nil).
function PanelController.showItem(key)
	local it = Cosmetics.get(key)
	if not it or not refs.panel then
		return nil
	end
	spotlight = key
	lockerKind = it.kind
	refs.spotY = nil
	PanelController.open("locker")
	if refs.spotY then
		refs.body.CanvasPosition = Vector2.new(0, math.max(0, refs.spotY - 40))
	end
	for _, c in refs.body:GetChildren() do
		if c:GetAttribute("Key") == key then
			return c
		end
	end
	return nil
end

function PanelController.spotlight()
	return spotlight
end

function PanelController.isOpen()
	return refs.panel ~= nil and refs.panel.Visible == true
end

function PanelController.toggle(tab)
	if PanelController.isOpen() and (tab == nil or tab == current) then
		PanelController.close()
	else
		PanelController.open(tab)
	end
end

function PanelController.tab()
	return current
end

function PanelController:init()
	gui = Theme.screen("Panel", 15, player:WaitForChild("PlayerGui"))
	build()
	-- the moving bits, while the panel's open (the gone ones dropped)
	RunService.RenderStepped:Connect(function()
		if #anims == 0 then
			return
		end
		local t = os.clock()
		for i = #anims, 1, -1 do
			local a = anims[i]
			if not a.inst.Parent then
				table.remove(anims, i)
			elseif PanelController.isOpen() then
				local ok = pcall(a.update, t)
				if not ok then
					table.remove(anims, i)
				end
			end
		end
	end)
	-- Tab opens the menu on its PLAYERS tab, so Roblox's own player list (also on Tab) steps aside
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	-- (the deal coming or going, the TNT bought: the shop follows while it's open)
	for _, a in { "Deal", "OwnsTNT" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			if PanelController.isOpen() and current == "shop" then
				PanelController.refresh()
			end
		end)
	end
	-- (players coming and going: the list follows while it's open)
	local function follow()
		if PanelController.isOpen() and current == "players" then
			PanelController.refresh()
		end
	end
	Players.PlayerAdded:Connect(follow)
	Players.PlayerRemoving:Connect(function()
		task.defer(follow)
	end)
	Layout.statusSink = function(s, kind)
		if PanelController.isOpen() then
			PanelController.status(s, kind)
			return true
		end
		return false
	end
	Store.Changed:Connect(function(partial)
		if partial.profile and PanelController.isOpen() then
			PanelController.refresh()
			-- a purchase the server has now given: celebrate it
			local w = pending
			if w and os.clock() > w.untilT then
				pending = nil
			elseif w and w.check(partial.profile) then
				pending = nil
				w.show()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			PanelController.toggle()
		elseif input.KeyCode == Enum.KeyCode.Tab then
			PanelController.toggle("players")
		elseif input.KeyCode == Enum.KeyCode.Escape and PanelController.isOpen() then
			if refs.overlay.Visible then
				if refs.tour then
					finishTour()
				else
					PanelController.closeDialog()
				end
			else
				PanelController.close()
			end
		end
	end)
end

return PanelController

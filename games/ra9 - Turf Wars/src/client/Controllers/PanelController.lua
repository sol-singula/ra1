--[[
The panel (B, or the SHOP button): four tabs, SUPERHOT-plain (white cards, black type, the team's colour):

  SHOP     today's 4 items and this week's bundle for Shards (◆), Shard packs, the Starter Pack (and the Shard Club
           when it's on); timers to the next rotation
  PASS     the season's Turf Pass: the tiers, free and premium, claim buttons, GET THE PASS, +1 TIER
  LOCKER   everything of a kind (trail, bow, kill effect, banner, title): yours to wear, or how to get it
  GOALS    VIP (earned, never bought) and how close you are, MVP, the goals and their rewards, and HOW TO PLAY
           (REPLAY: the first-game tutorial again)

While it's open the mouse is free, the HUD's middle steps aside (Layout.setPanel) and toasts show on the panel's own
line at the bottom. Every piece has its own slot (the numbers below), so nothing lands on anything (ClientSmoke
checks).

  PanelController.open(tab?)   .close()   .toggle()   .tab()   .refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Achievements = require(ReplicatedStorage.Shared.Data.Achievements)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Ladder = require(ReplicatedStorage.Shared.Data.Ladder)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)

local PanelController = { Name = "PanelController", Order = 48 }

local C = Theme.Color
local LIGHT = Color3.fromRGB(232, 232, 234)
local PREVIEW_BG = Color3.fromRGB(200, 201, 205)
local player = Players.LocalPlayer

-- The geometry (design pixels): the panel sits under the top bar, clear of the corners (the kill feed and popup
-- stack on the right start at x 924 on a 1240 canvas, the panel ends at 920)
local P = { w = 600, h = 450, top = 96, head = 44, bodyY = 52, bodyH = 352, footY = 412, footH = 26 }
local W = 564 -- the body's content width (inside its scroll bar)
PanelController.P = P

local TABS = { { "shop", "SHOP" }, { "pass", "PASS" }, { "locker", "LOCKER" }, { "goals", "GOALS" } }
local refs = {}
PanelController.refs = refs
local current = "shop"
local lockerKind = "trail"
local gui

local function profile()
	return Store.get("profile") or {}
end

local function now()
	return workspace:GetServerTimeNow()
end

local function money(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

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

local function frame(parent, name, x, y, w, h, color)
	return Theme.new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
end

local function button(parent, name, label, x, y, w, h, dark, onClick)
	local b = Theme.new("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = dark and C.ink or C.white,
		Text = "",
		AutoButtonColor = true,
		Parent = parent,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	text(b, {
		Name = "Label",
		Text = label,
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.fromOffset(4, 3),
		fit = 14,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = dark and C.white or C.ink,
	})
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function label(parent, name, s, x, y, w, h, size, color, align)
	return text(parent, {
		Name = name,
		Text = s,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		fit = size or 13,
		TextColor3 = color or C.ink,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Font = Theme.Body,
	})
end

-- A small picture of a cosmetic in a w x h box
local GLYPH = { cubes = "▪ ▪ ▪", ring = "◯", shards = "✶", pixels = "▦", rise = "⇡", spotlight = "☼" }
local function preview(parent, it, x, y, w, h)
	local box = Theme.new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = PREVIEW_BG,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, { Theme.corner(3) })
	if not it then
		return box
	end
	local team = Store.team() or "red"
	local look = it.look or {}
	local function bar(px, py, bw, bh, color, rot)
		return Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, px, 0, py),
			Size = UDim2.fromOffset(bw, bh),
			Rotation = rot or 0,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = box,
		})
	end
	local cx, cy = w / 2, h / 2
	if it.kind == "trail" then
		local len = math.min(w - 16, (w - 16) * 0.6 * (look.length or 1))
		bar(cx, cy, len, 4, Cosmetics.color("team", team))
		for _, l in look.lines or {} do
			local dy = (l[1] + l[2]) * 26
			local th = math.max(2, l[3] * 18)
			local c = Cosmetics.color(l[4], team)
			if look.dash then
				for i = 0, 3 do
					bar(cx - len / 2 + len * (i + 0.5) / 4, cy + dy, len / 8, th, c)
				end
			else
				bar(cx, cy + dy, len, th, c)
			end
		end
		for i = 1, look.ghost or 0 do
			bar(cx + len / 2 - i * 10, cy - 8, 6, 3, C.white)
		end
	elseif it.kind == "skin" then
		local limb = Cosmetics.color(look.limbs, team)
		bar(cx, cy - h * 0.2, 5, h * 0.36, limb, 20)
		bar(cx, cy + h * 0.2, 5, h * 0.36, limb, -20)
		bar(cx + 2, cy, 8, h * 0.22, Cosmetics.color(look.grip, team))
	elseif it.kind == "effect" then
		text(box, {
			Text = GLYPH[look.shape] or "✶",
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Cosmetics.color(look.color, team),
			Font = Theme.Display,
		})
	elseif it.kind == "banner" then
		local flag = bar(cx, cy, math.min(w * 0.5, h * 0.8), h * 0.8, Cosmetics.color("team", team))
		text(flag, {
			Text = look.emblem or "★",
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.white,
			Font = Theme.Display,
		})
	else
		text(box, {
			Text = string.upper(look.text or it.name),
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			fit = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
		})
	end
	return box
end
PanelController.preview = preview

local RARITY = { common = "COMMON", rare = "RARE ★", epic = "EPIC ★★", legendary = "LEGENDARY ★★★" }

-- The tabs' bodies ----------------------------------------------------------------------------------------------
local function section(body, name, s, y)
	label(body, name, s, 0, y, W, 18, 13, C.muted)
	return y + 22
end

local function shopTab(body)
	local p = profile()
	local t = now()
	local day = Shop.dayOf(t)
	local y = section(body, "TodayLabel", `TODAY  ·  NEW ITEMS IN {span((day + 1) * 86400 - t)}`, 0)
	local cw = (W - 3 * 8) / 4
	for i, key in Shop.daily(day, player:GetAttribute("ShopRoll")) do
		local it = Cosmetics.get(key)
		local card = frame(body, "Item" .. i, (i - 1) * (cw + 8), y, cw, 156)
		label(card, "Kind", Cosmetics.KIND_NAME[it.kind], 8, 6, cw - 16, 14, 11, C.muted)
		preview(card, it, 8, 24, cw - 16, 56)
		label(card, "Name", it.name, 8, 84, cw - 16, 18, 14)
		label(card, "Rarity", RARITY[it.rarity], 8, 102, cw - 16, 14, 11, C.muted)
		local owned = Locker.owns(p, key)
		local worn = (p.equipped or {})[it.kind] == key
		local cta = worn and "WORN" or (owned and "WEAR" or `◆ {money(Shop.price(it))}`)
		button(card, "Buy", cta, 8, 118, cw - 16, 30, not owned, function()
			if owned then
				Net.send("Settings", "equip", { kind = it.kind, key = key })
			else
				Net.send("Buy", "item", key)
			end
		end)
	end
	y += 156 + 10
	local week = Shop.weekOf(t)
	local bundle = Shop.weekly(week)
	local weekEnds = ((week + 1) * 7 - 3) * 86400
	y = section(body, "WeekLabel", `THIS WEEK'S BUNDLE  ·  30% OFF  ·  ENDS IN {span(weekEnds - t)}`, y)
	local bc = frame(body, "Bundle", 0, y, W, 84)
	local all = true
	for i, key in bundle.keys do
		local it = Cosmetics.get(key)
		preview(bc, it, 8 + (i - 1) * 96, 8, 88, 44)
		label(bc, "BName" .. i, it.name, 8 + (i - 1) * 96, 56, 88, 16, 12)
		all = all and Locker.owns(p, key)
	end
	button(bc, "BuyBundle", all and "OWNED" or `◆ {money(bundle.price)}`, W - 150, 24, 140, 36, not all, function()
		if not all then
			Net.send("Buy", "bundle")
		end
	end)
	y += 84 + 10
	y = section(body, "ShardsLabel", "GET SHARDS  ·  ◆ BUY ANYTHING IN THE SHOP", y)
	for i, pack in Shop.PACKS do
		local card = frame(body, "Pack" .. i, (i - 1) * (cw + 8), y, cw, 96)
		label(card, "Name", pack.name, 8, 6, cw - 16, 16, 12, C.muted)
		label(card, "Amount", `◆ {money(pack.shards)}`, 8, 24, cw - 16, 24, 20)
		label(card, "Tag", pack.tag or "", 8, 50, cw - 16, 12, 11, C.red)
		button(card, "BuyPack", `R$ {pack.robux}`, 8, 64, cw - 16, 26, true, function()
			Net.send("Buy", "robux", pack.key)
		end)
	end
	y += 96 + 10
	local oneTime = not p.starter or Shop.CLUB.subscriptionId ~= nil
	if oneTime then
		y = section(body, "OnceLabel", "ONE TIME", y)
		local x = 0
		local half = (W - 8) / 2
		if not p.starter then
			local card = frame(body, "Starter", x, y, half, 64)
			label(card, "Name", Shop.STARTER.name, 10, 8, half - 130, 18, 15)
			label(card, "Desc", Shop.STARTER.desc, 10, 30, half - 130, 26, 12, C.muted)
			button(card, "BuyStarter", `R$ {Shop.STARTER.robux}`, half - 110, 16, 100, 32, true, function()
				Net.send("Buy", "robux", "starter")
			end)
			x += half + 8
		end
		if Shop.CLUB.subscriptionId then
			local card = frame(body, "Club", x, y, half, 64)
			label(card, "Name", Shop.CLUB.name, 10, 8, half - 130, 18, 15)
			label(card, "Desc", Shop.CLUB.desc, 10, 30, half - 130, 26, 12, C.muted)
			button(card, "JoinClub", "JOIN", half - 110, 16, 100, 32, true, function()
				pcall(function()
					game:GetService("MarketplaceService"):PromptSubscriptionPurchase(player, Shop.CLUB.subscriptionId)
				end)
			end)
		end
		y += 64 + 10
	end
	return y
end

local function passTab(body)
	local p = profile()
	local s = p.season or { n = Season.at(now()).n, xp = 0, claimed = {} }
	local info = Season.at(now())
	label(body, "Season", s.name or Season.name(s.n), 0, 0, W - 150, 24, 18)
	label(
		body,
		"Ends",
		`ENDS IN {span(info.endsAt - now())}`,
		W - 140,
		0,
		140,
		24,
		13,
		C.muted,
		Enum.TextXAlignment.Right
	)
	local tier = Season.tierOf(s.xp)
	local into = (s.xp or 0) - tier * Season.XP_PER_TIER
	local bar, fill = Theme.bar({
		Name = "Progress",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.fromOffset(W, 16),
		BackgroundColor3 = LIGHT,
		Parent = body,
	}, C.ink)
	fill.Size = UDim2.fromScale(tier >= Season.TIERS and 1 or into / Season.XP_PER_TIER, 1)
	_ = bar
	label(
		body,
		"TierText",
		tier >= Season.TIERS and `TIER {tier} / {Season.TIERS}  ·  ALL DONE`
			or `TIER {tier} / {Season.TIERS}  ·  {into} / {Season.XP_PER_TIER} XP TO TIER {tier + 1}`,
		0,
		50,
		W,
		16,
		12,
		C.muted
	)
	button(
		body,
		"GetPass",
		s.premium and "PREMIUM ✓" or `GET THE TURF PASS  ·  R$ {Shop.PASS.robux}`,
		0,
		72,
		300,
		36,
		not s.premium,
		function()
			if not s.premium then
				Net.send("Buy", "robux", "pass")
			end
		end
	)
	button(body, "AddTier", `+1 TIER  ·  R$ {Shop.TIER.robux}`, 312, 72, 200, 36, false, function()
		Net.send("Buy", "robux", "tier")
	end)
	label(body, "HTier", "TIER", 0, 120, 60, 16, 11, C.muted)
	label(body, "HFree", "FREE", 70, 120, 240, 16, 11, C.muted)
	label(body, "HPrem", "PREMIUM", 320, 120, 244, 16, 11, C.muted)
	local y = 140
	for t = 1, Season.TIERS do
		local row = Theme.new("Frame", {
			Name = "Tier" .. t,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(W, 40),
			BackgroundTransparency = 1,
			Parent = body,
		})
		label(row, "N", tostring(t), 0, 0, 60, 40, 18, t <= tier and C.ink or C.muted)
		for _, track in { { "f", 70, 240 }, { "p", 320, 244 } } do
			local key, x, cw = track[1], track[2], track[3]
			local r = Season.reward(s.n, t, key)
			local cell = frame(row, key == "f" and "Free" or "Prem", x, 0, cw, 40, (t <= tier) and C.white or LIGHT)
			if r then
				local what
				if r.kind == "shards" then
					what = `◆ {r.amount}`
				else
					local it = Cosmetics.get(r.key)
					what = it and `{it.name}  ·  {Cosmetics.KIND_NAME[it.kind]}` or "?"
				end
				label(cell, "What", what, 8, 0, cw - 92, 40, 12)
				local claimed = (s.claimed or {})[tostring(t) .. key]
				local locked = t > tier or (key == "p" and not s.premium)
				local cta = claimed and "✓" or (locked and "🔒" or "CLAIM")
				button(cell, "Claim", cta, cw - 80, 6, 72, 28, not claimed and not locked, function()
					if not claimed and not locked then
						Net.send("Claim", t, key)
					end
				end)
			end
		end
		y += 46
	end
	return y
end

local function lockerTab(body)
	local p = profile()
	local cw = (W - 4 * 6) / 5
	for i, k in Cosmetics.KINDS do
		button(body, "Chip_" .. k, Cosmetics.KIND_NAME[k], (i - 1) * (cw + 6), 0, cw, 28, k == lockerKind, function()
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
	local y = 36
	for i, it in items do
		local col = (i - 1) % 4
		local x = col * (gw + 8)
		local owned = it.key == false or Locker.owns(p, it.key)
		local worn = it.key == false and (p.equipped or {})[lockerKind] == nil
			or (p.equipped or {})[lockerKind] == it.key
		local card = Theme.new("TextButton", {
			Name = "Item" .. i,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(gw, 100),
			BackgroundColor3 = worn and C.ink or (owned and C.white or LIGHT),
			Text = "",
			AutoButtonColor = owned,
			Parent = body,
		}, { Theme.corner(4), Theme.stroke(2, C.ink) })
		card:SetAttribute("Key", it.key or "")
		if it.key then
			preview(card, it, 8, 6, gw - 16, 40)
		end
		label(card, "Name", it.name, 8, 50, gw - 16, 18, 13, worn and C.white or C.ink)
		local line = worn and "WORN" or (owned and "WEAR" or ("🔒 " .. Locker.how(it)))
		label(card, "Line", line, 8, 72, gw - 16, 20, 11, worn and C.white or C.muted)
		if owned then
			card.Activated:Connect(function()
				Net.send("Settings", "equip", { kind = lockerKind, key = it.key or nil })
			end)
		end
		if col == 3 then
			y += 108
		end
	end
	if #items % 4 ~= 0 then
		y += 108
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
		label(row, "Name", (done and "✓ " or "") .. g.name, 10, 6, 330, 20, 15)
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
		local _, fill = Theme.bar({
			Name = "Bar",
			Position = UDim2.fromOffset(10, 46),
			Size = UDim2.fromOffset(W - 20, 6),
			BackgroundColor3 = C.white,
			Parent = row,
		}, C.ink)
		fill.Size = UDim2.fromScale(have / g.goal, 1)
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

local BUILD = { shop = shopTab, pass = passTab, locker = lockerTab, goals = goalsTab }

-- The panel -----------------------------------------------------------------------------------------------------
function PanelController.refresh()
	if not refs.panel then
		return
	end
	local p = profile()
	refs.shards.Label.Text = `◆ {money(p.shards or 0)}`
	for _, t in TABS do
		local b = refs.tabs[t[1]]
		local on = t[1] == current
		b.BackgroundColor3 = on and C.ink or C.white
		b.Label.TextColor3 = on and C.white or C.ink
	end
	local body = refs.body
	local keep = current == refs.lastTab and body.CanvasPosition or Vector2.zero
	for _, c in body:GetChildren() do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
	local h = BUILD[current](body)
	body.CanvasSize = UDim2.fromOffset(0, h)
	body.CanvasPosition = keep
	refs.lastTab = current
end

function PanelController.status(s, kind)
	if refs.status then
		refs.status.Text = s or ""
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
		refs.tabs[t[1]] = button(panel, "Tab_" .. t[1], t[2], 10 + (i - 1) * 100, 6, 94, 32, false, function()
			PanelController.open(t[1])
		end)
	end
	refs.shards = button(panel, "Shards", "◆ 0", 414, 6, 120, 32, false, function()
		PanelController.open("shop")
	end)
	refs.close = button(panel, "Close", "✕", 548, 6, 42, 32, true, function()
		PanelController.close()
	end)
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
end

function PanelController.open(tab)
	if not refs.panel then
		return
	end
	current = tab or current
	Layout.claimPanel("panel", PanelController.close)
	refs.panel.Visible = true
	PanelController.status("")
	Layout.modal("panel", refs.panel)
	Layout.setPanel(true)
	PanelController.refresh()
end

function PanelController.close()
	if refs.panel then
		refs.panel.Visible = false
	end
	Layout.setPanel(false)
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
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			PanelController.toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and PanelController.isOpen() then
			PanelController.close()
		end
	end)
end

return PanelController

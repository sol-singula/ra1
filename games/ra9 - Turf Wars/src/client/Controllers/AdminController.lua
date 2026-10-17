--[[
The admin panel, for admins only (the server sets the "Admin" attribute on you; everyone else never sees any of
this, and the server refuses everything they send anyway). An ADMIN button at the top left, right of the INVITE
and SHOP buttons, opens it. Four tabs, in the shop panel's SUPERHOT look:

  SERVERS  every live server of the game: its map, phase, score and players; JOIN goes there to spectate unseen
  MATCH    end it now (red, blue or a draw), skip to the fight or the build, stop the clock, a new match or map,
           bots on or off, a message for everyone
  PLAYERS  pick a player: their team, knock out, heal, go to them, bring them, MVP, VIP (for a while or for good),
           Shards, pass tiers, reset their shop, kick, give any cosmetic
  ME       spectate (watch unseen), invisible, unlock everything, Shards for yourself

While spectating (or invisible) a small tag under the button says so. Every press sends Net "Admin" (action,
target, value); the server checks it, does it, and sends the panel's data back (Net "AdminState").

  AdminController.open(tab?)   .close()   .toggle()   .isOpen()   .tab()   .state()   .refs
  AdminController.select(userId)   the player the PLAYERS tab works on
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local Device = require(script.Parent.Parent.UI.Device)
local SpectateController = require(script.Parent.SpectateController)

local AdminController = { Name = "AdminController", Order = 49 }

local C = Theme.Color
local RED, BLUE = Constants.TEAM_COLOR.red, Constants.TEAM_COLOR.blue
local player = Players.LocalPlayer

-- The geometry (design pixels): the same box as the shop panel, so nothing new lands on the HUD
local P = { w = 600, h = 450, top = 96, bodyY = 52, bodyH = 352, footY = 412, footH = 26 }
local W = 564 -- the body's content width (inside its scroll bar)
local ROW = 36 -- a row of buttons
AdminController.P = P

local TABS = { { "servers", "SERVERS" }, { "match", "MATCH" }, { "players", "PLAYERS" }, { "me", "ME" } }
local refs = {}
AdminController.refs = refs
local current = "match"
local state = { players = {} } -- the server's last AdminState
local servers -- the last server list (nil until asked)
local selected -- the UserId the PLAYERS tab works on
local kind = "trail" -- the cosmetics shown
local drafts = {} -- [box name] = what's typed (kept across redraws)
local gui

local function send(action, target, value)
	Net.send("Admin", action, target, value)
end

-- Pieces (as in the shop panel) ---------------------------------------------------------------------------------
local function text(parent, props)
	props.Parent = parent
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
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

-- color: nil (white, ink letters), "dark" (ink), or a Color3 (white letters)
local function button(parent, name, s, x, y, w, h, color, onClick)
	local bg = color == "dark" and C.ink or (typeof(color) == "Color3" and color or C.white)
	local b = Theme.new("TextButton", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = bg,
		Text = "",
		AutoButtonColor = true,
		Parent = parent,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	text(b, {
		Name = "Label",
		Text = s,
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.fromOffset(4, 3),
		fit = 14,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color and C.white or C.ink,
	})
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function section(body, name, s, y)
	label(body, name, s, 0, y, W, 18, 13, C.muted)
	return y + 22
end

-- A row of equal buttons across the body: { { name, label, onClick, color? } }
local function row(body, y, specs)
	local gap = 8
	local w = (W - gap * (#specs - 1)) / #specs
	for i, s in specs do
		button(body, s[1], s[2], (i - 1) * (w + gap), y, w, ROW, s[4], s[3])
	end
	return y + ROW + 8
end

-- A text box (what's typed survives the panel redrawing)
local function box(body, name, hint, x, y, w)
	local b = Theme.new("TextBox", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, ROW),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Text = drafts[name] or "",
		PlaceholderText = hint,
		PlaceholderColor3 = C.muted,
		ClearTextOnFocus = false,
		Font = Theme.Body,
		TextSize = 15,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	}, { Theme.corner(4), Theme.stroke(2, C.ink), Theme.padding(8) })
	pcall(function()
		b:GetPropertyChangedSignal("Text"):Connect(function()
			drafts[name] = b.Text
		end)
	end)
	return b
end

local function find(userId)
	for _, p in state.players or {} do
		if p.id == userId then
			return p
		end
	end
	return nil
end

local function toggle(on, s)
	return `{s}: {on and "ON" or "OFF"}`
end

-- The tabs' bodies ----------------------------------------------------------------------------------------------
local function serversTab(body)
	local y = row(body, 0, {
		{
			"Refresh",
			"REFRESH",
			function()
				send("servers")
			end,
			"dark",
		},
	})
	y = section(body, "Help", "Every live server. JOIN to watch it unseen.", y)
	if not servers then
		label(body, "Loading", "Loading...", 0, y, W, 20, 14)
		return y + 24
	elseif #servers == 0 then
		label(body, "Empty", "No servers found yet. Tap REFRESH.", 0, y, W, 20, 14)
		return y + 24
	end
	for i, s in servers do
		local card = Theme.new("Frame", {
			Name = "Server" .. i,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(W, 66),
			BackgroundColor3 = s.here and Color3.fromRGB(236, 236, 238) or C.white,
			BorderSizePixel = 0,
			Parent = body,
		}, { Theme.corner(4), Theme.stroke(2, C.ink) })
		label(
			card,
			"Line",
			`{string.upper(s.map or "?")} · {string.upper(s.phase or "?")} · {s.players or 0} ON · RED {s.red or 0} · BLUE {s.blue or 0}`,
			10,
			6,
			W - 130,
			20,
			14
		)
		label(card, "Names", table.concat(s.names or {}, ", "), 10, 28, W - 130, 30, 12, C.muted)
		if s.here then
			button(card, "Join", "YOU'RE HERE", W - 110, 15, 100, ROW, nil, nil)
		else
			button(card, "Join", "JOIN", W - 110, 15, 100, ROW, "dark", function()
				send("join", nil, s.jobId)
			end)
		end
		y += 74
	end
	return y
end

local function matchTab(body)
	local m = Maps.get(state.map)
	local y = section(
		body,
		"Now",
		`MAP {string.upper(m and m.name or "?")} · {string.upper(state.phase or "?")}{state.frozen and " · CLOCK STOPPED" or ""}`,
		0
	)
	y = section(body, "EndLabel", "END THE MATCH NOW", y)
	y = row(body, y, {
		{
			"RedWins",
			"RED WINS",
			function()
				send("end", nil, "red")
			end,
			RED,
		},
		{
			"BlueWins",
			"BLUE WINS",
			function()
				send("end", nil, "blue")
			end,
			BLUE,
		},
		{
			"Draw",
			"DRAW",
			function()
				send("end", nil, "draw")
			end,
			"dark",
		},
	})
	y = section(body, "ClockLabel", "THE CLOCK", y)
	y = row(body, y, {
		{
			"SkipFight",
			"SKIP TO FIGHT",
			function()
				send("skip", nil, "fight")
			end,
		},
		{
			"SkipBuild",
			"SKIP TO BUILD",
			function()
				send("skip", nil, "build")
			end,
		},
		{
			"SkipCharge",
			"SKIP TO CHARGE",
			function()
				send("skip", nil, "charge")
			end,
		},
		{
			"Freeze",
			state.frozen and "START CLOCK" or "STOP CLOCK",
			function()
				send("freeze", nil, not state.frozen)
			end,
			state.frozen and "dark" or nil,
		},
	})
	y = section(body, "MapLabel", "NEW MATCH", y)
	y = row(body, y, {
		{
			"Restart",
			"RESTART THIS MAP",
			function()
				send("restart")
			end,
			"dark",
		},
		{
			"Bots",
			toggle(state.bots, "BOTS"),
			function()
				send("bots", nil, not state.bots)
			end,
			state.bots and "dark" or nil,
		},
	})
	local maps = {}
	for _, mp in Maps.list do
		table.insert(maps, {
			"Map_" .. mp.key,
			string.upper(mp.name),
			function()
				send("map", nil, mp.key)
			end,
		})
	end
	y = row(body, y, maps)
	y = section(body, "AnnounceLabel", "A MESSAGE FOR EVERYONE", y)
	local msg = box(body, "Message", "Type a message...", 0, y, W - 128)
	button(body, "Send", "SEND", W - 120, y, 120, ROW, RED, function()
		send("announce", nil, msg.Text)
		drafts.Message = ""
		msg.Text = ""
	end)
	return y + ROW + 8
end

local function playersTab(body)
	local list = state.players or {}
	local y = section(body, "Count", `PLAYERS IN THIS SERVER ({#list})`, 0)
	local cols, gap = 4, 8
	local cw = (W - gap * (cols - 1)) / cols
	for i, p in list do
		local cx = ((i - 1) % cols) * (cw + gap)
		local cy = y + ((i - 1) // cols) * (34 + gap)
		local on = p.id == selected
		local b = button(body, "Player_" .. p.id, p.name, cx, cy, cw, 34, on and "dark" or nil, function()
			AdminController.select(p.id)
		end)
		if not on then
			b.Label.TextColor3 = Constants.TEAM_COLOR[p.team or ""] or C.ink
		end
	end
	y += math.ceil(#list / cols) * (34 + gap) + 4
	local p = find(selected)
	if not p then
		label(body, "Pick", "Pick a player.", 0, y, W, 20, 14, C.muted)
		return y + 24
	end
	local id = p.id
	local about = string.upper(p.name)
		.. (p.spectating and " · SPECTATING" or (p.team and ` · TEAM {Constants.TEAM_NAME[p.team]}` or ""))
		.. (p.alive and "" or " · DOWN")
		.. (p.vip and " · VIP" or "")
		.. (p.admin and " · ADMIN" or "")
	y = section(body, "About", about, y)
	y = row(body, y, {
		{
			"TeamRed",
			"RED TEAM",
			function()
				send("team", id, "red")
			end,
			RED,
		},
		{
			"TeamBlue",
			"BLUE TEAM",
			function()
				send("team", id, "blue")
			end,
			BLUE,
		},
		{
			"Kill",
			"KNOCK OUT",
			function()
				send("kill", id)
			end,
			"dark",
		},
		{
			"Heal",
			p.alive and "HEAL" or "RESPAWN",
			function()
				send("heal", id)
			end,
		},
	})
	y = row(body, y, {
		{
			"Goto",
			state.spectating and "WATCH" or "GO TO",
			function()
				send("goto", id)
			end,
		},
		{
			"Bring",
			"BRING",
			function()
				send("bring", id)
			end,
		},
		{
			"Mvp",
			"MAKE MVP",
			function()
				send("mvp", id)
			end,
			"dark",
		},
		{
			"ResetShop",
			"RESET SHOP",
			function()
				send("resetshop", id)
			end,
		},
	})
	y = row(body, y, {
		{
			"SendTutorial",
			"SEND TO TUTORIAL",
			function()
				send("tutorial", id)
			end,
		},
	})
	y = section(body, "VipLabel", "GIVE VIP", y)
	local vips = {}
	for _, v in Constants.ADMIN_VIP do
		table.insert(vips, {
			"Vip_" .. v[1],
			v[3],
			function()
				send("vip", id, v[1])
			end,
		})
	end
	table.insert(vips, {
		"Vip_remove",
		"REMOVE",
		function()
			send("vip", id, "remove")
		end,
		"dark",
	})
	y = row(body, y, vips)
	y = section(body, "GiveLabel", "GIVE SHARDS AND PASS TIERS", y)
	y = row(body, y, {
		{
			"Shards100",
			"+100 ◆",
			function()
				send("shards", id, 100)
			end,
		},
		{
			"Shards1000",
			"+1,000 ◆",
			function()
				send("shards", id, 1000)
			end,
		},
		{
			"Shards10000",
			"+10,000 ◆",
			function()
				send("shards", id, 10000)
			end,
		},
		{
			"Tiers1",
			"+1 TIER",
			function()
				send("tiers", id, 1)
			end,
		},
		{
			"Tiers5",
			"+5 TIERS",
			function()
				send("tiers", id, 5)
			end,
		},
		{
			"Tiers30",
			"+30 TIERS",
			function()
				send("tiers", id, 30)
			end,
		},
	})
	y = section(body, "KickLabel", "KICK", y)
	local why = box(body, "Reason", "Why? (they see this)", 0, y, W - 128)
	button(body, "Kick", "KICK", W - 120, y, 120, ROW, RED, function()
		send("kick", id, why.Text)
		drafts.Reason = ""
	end)
	y += ROW + 8
	y = section(body, "CosmeticLabel", "GIVE A COSMETIC (THEY WEAR IT)", y)
	local kinds = {}
	for _, k in Cosmetics.KINDS do
		table.insert(kinds, {
			"Kind_" .. k,
			Cosmetics.KIND_NAME[k],
			function()
				kind = k
				AdminController.refresh()
			end,
			kind == k and "dark" or nil,
		})
	end
	y = row(body, y, kinds)
	local items = {}
	for _, key in Locker.every(Season.at(math.floor(workspace:GetServerTimeNow())).n) do
		local it = Cosmetics.get(key)
		if it and it.kind == kind then
			table.insert(items, it)
		end
	end
	for i, it in items do
		local cx = ((i - 1) % cols) * (cw + gap)
		local cy = y + ((i - 1) // cols) * (30 + gap)
		button(body, "Item_" .. it.key, it.name, cx, cy, cw, 30, nil, function()
			send("cosmetic", id, it.key)
		end)
	end
	return y + math.ceil(#items / cols) * (30 + gap)
end

local function meTab(body)
	local y = section(
		body,
		"Now",
		state.mission and "YOU'RE IN MISSION CONTROL"
			or state.afk and "YOU'RE IN THE AFK ROOM"
			or state.spectating and "YOU'RE SPECTATING: NOBODY CAN SEE YOU"
			or (state.invisible and "YOU'RE INVISIBLE (STILL PLAYING)" or "YOU'RE PLAYING"),
		0
	)
	y = row(body, y, {
		{
			"Spectate",
			toggle(state.spectating, "SPECTATE"),
			function()
				send("spectate", nil, not state.spectating)
			end,
			state.spectating and "dark" or nil,
		},
		{
			"Invisible",
			toggle(state.invisible, "INVISIBLE"),
			function()
				send("invisible", nil, not state.invisible)
			end,
			state.invisible and "dark" or nil,
		},
	})
	y = row(body, y, {
		{
			"WatchPlayer",
			"WATCH A PLAYER",
			function()
				-- (spectate, then the list of everyone to pick from)
				if not state.spectating then
					send("spectate", nil, true)
				end
				AdminController.close()
				task.delay(0.4, function()
					SpectateController.showList(true)
				end)
			end,
		},
		{
			"FreeRoam",
			"FREE ROAM",
			function()
				if not state.spectating then
					send("spectate", nil, true)
				end
				AdminController.close()
				task.delay(0.4, SpectateController.free)
			end,
		},
	})
	y = row(body, y, {
		{
			"Tutorial",
			"PLAY TUTORIAL",
			function()
				send("tutorial")
				AdminController.close() -- (out of the way: the tutorial has the screen)
			end,
		},
		{
			"Mission",
			state.mission and "LEAVE MISSION CONTROL" or "MISSION CONTROL",
			function()
				send("mission", nil, not state.mission)
				if not state.mission then
					AdminController.close() -- (out of the way: the screens are the show)
				end
			end,
			state.mission and "dark" or RED,
		},
		{
			"AfkRoom",
			state.afk and "LEAVE AFK ROOM" or "GO TO AFK ROOM",
			function()
				send("afkroom", nil, not state.afk)
			end,
			state.afk and "dark" or nil,
		},
	})
	y = row(body, y, {
		{
			"UnlockAll",
			"UNLOCK ALL",
			function()
				send("unlockall")
			end,
			RED,
		},
		{
			"MyShards1000",
			"+1,000 ◆",
			function()
				send("shards", player.UserId, 1000)
			end,
		},
		{
			"MyShards10000",
			"+10,000 ◆",
			function()
				send("shards", player.UserId, 10000)
			end,
		},
		{
			"MyTiers",
			"+5 TIERS",
			function()
				send("tiers", player.UserId, 5)
			end,
		},
	})
	y = section(body, "HelpLabel", "SPECTATING", y)
	label(
		body,
		"Help",
		"WASD to fly, the mouse to look, Space to go up, Shift to go down, Ctrl to go fast. F to follow a player, the arrow keys for the next one. On a phone: drag to look, hold FLY.",
		0,
		y,
		W,
		56,
		13
	)
	return y + 60
end

local BUILD = { servers = serversTab, match = matchTab, players = playersTab, me = meTab }

-- The panel -----------------------------------------------------------------------------------------------------
function AdminController.refresh()
	if not refs.panel then
		return
	end
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

function AdminController.status(s, kindOf)
	if refs.status then
		refs.status.Text = s or ""
		refs.status.TextColor3 = kindOf == "bad" and C.red or C.ink
	end
end

local function buildPanel()
	local panel = Theme.card({
		Name = "AdminPanel",
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
		refs.tabs[t[1]] = button(panel, "Tab_" .. t[1], t[2], 10 + (i - 1) * 100, 6, 94, 32, nil, function()
			AdminController.open(t[1])
		end)
	end
	label(panel, "Title", "ADMIN", 414, 6, 120, 32, 18, C.red, Enum.TextXAlignment.Center).Font = Theme.Display
	refs.close = Theme.closeButton(panel, function()
		AdminController.close()
	end, { Position = UDim2.fromOffset(P.w - 46, 4) })
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

-- The button and the tag, top left: right of SHOP (INVITE and SHOP end at x 216, the PARTY button sits right of
-- INVITE, the top bar starts at 340), the tag under the button
local function buildButton()
	local b = Theme.new("TextButton", {
		Name = "AdminButton",
		Position = UDim2.fromOffset(224, 74),
		Size = UDim2.fromOffset(104, 50),
		BackgroundColor3 = C.red,
		Text = "",
		AutoButtonColor = true,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	Theme.title({
		Name = "Head",
		Text = "ADMIN",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 5),
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = false,
		Parent = b,
	})
	text(b, {
		Name = "Line",
		Text = "panel",
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.fromOffset(6, 28),
		fit = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
	})
	b.Activated:Connect(function()
		AdminController.toggle()
	end)
	refs.button = b
	local tag = Theme.new("Frame", {
		Name = "SpectateTag",
		Position = UDim2.fromOffset(224, 132),
		Size = UDim2.fromOffset(104, 50),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.red) })
	refs.tagText = text(tag, {
		Name = "Text",
		Text = "SPECTATING (invisible)",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		fit = 13,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.red,
	})
	refs.tag = tag
end

local function update()
	local admin = player:GetAttribute("Admin") == true
	local watching = player:GetAttribute("Spectating") == true
	local hidden = player:GetAttribute("Invisible") == true
	if refs.button then
		refs.button.Visible = admin
		-- (on a phone the health bar sits under SHOP, so the button's own second line says it instead of the tag)
		local touch = Device.isTouch()
		refs.tag.Visible = admin and (watching or hidden) and not touch
		refs.tagText.Text = watching and "SPECTATING (invisible)" or "INVISIBLE"
		local line = refs.button:FindFirstChild("Line")
		if line then
			line.Text = (touch and watching) and "spectating" or ((touch and hidden) and "invisible" or "panel")
		end
		-- (clickable with the mouse while spectating: no first person to let go of)
		refs.button.Modal = watching
	end
	if not admin and AdminController.isOpen() then
		AdminController.close()
	end
end
AdminController.update = update

function AdminController.open(tab)
	if not refs.panel or player:GetAttribute("Admin") ~= true then
		return
	end
	current = tab or current
	Layout.claimPanel("admin", AdminController.close)
	refs.panel.Visible = true
	AdminController.status("")
	Layout.modal("admin", refs.panel)
	Layout.setPanel(true)
	send(current == "servers" and "servers" or "state")
	AdminController.refresh()
end

function AdminController.close()
	if refs.panel and refs.panel.Visible then
		refs.panel.Visible = false
		Layout.setPanel(false)
	end
end

function AdminController.isOpen()
	return refs.panel ~= nil and refs.panel.Visible == true
end

function AdminController.toggle(tab)
	if AdminController.isOpen() and (tab == nil or tab == current) then
		AdminController.close()
	else
		AdminController.open(tab)
	end
end

function AdminController.tab()
	return current
end

function AdminController.state()
	return state
end

function AdminController.select(userId)
	selected = userId
	AdminController.refresh()
end

function AdminController:init()
	gui = Theme.screen("Admin", 16, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildButton()
	buildPanel()
	for _, attr in { "Admin", "Spectating", "Invisible" } do
		player:GetAttributeChangedSignal(attr):Connect(update)
	end
	update()
	Net.listen("AdminState", function(s)
		if type(s) ~= "table" then
			return
		end
		state = s
		if s.servers then
			servers = s.servers
		end
		if s.follow then
			SpectateController.follow(s.follow)
		end
		if AdminController.isOpen() then
			AdminController.refresh()
		end
	end)
	-- (the server's answers show on the panel's own line while it's open)
	Net.listen("Toast", function(s, kindOf)
		if AdminController.isOpen() then
			AdminController.status(s, kindOf)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and AdminController.isOpen() then
			AdminController.close()
		end
	end)
end

return AdminController

--[[
The lobby's screen and its world (Modes = { "lobby" }: only in the lobby place; LobbyService runs the server side),
phone-first: big buttons, the SUPERHOT look (white cards, black type, gold for PLAY).

  bottom centre  ▶ PLAY, big and gold: "joins the fullest game · N playing"; above it four mode cards (Turf Wars,
                 Capture the Flag, Bot Brawl, Castle Tycoon) with their live counts (Net "Population"); a tap sends Net "Play"
                 (with the card's mode; the framework's PlaceService teleports)
  top left       🛒 SHOP (the panel: PanelController) and your Shards under it
  top right      🏆 TOP: LeaderboardController's own button and panel
  top centre     the parkour clock while you climb (PARKOUR 0:12.3 · 2/4), toasts under the PLAY block
  the card       LIKE TURF WARS? 👍 "If you like the game, tap VERIFY to tell us": VERIFY sends Net "Verify" (a
                 thank-you once: Shards and the Supporter banner), LATER closes it; verified, it says thanks

In the world (polled a few times a second, with a prompt on each for E / X / a tap): walking onto the PLAY dais
plays; into a portal plays its mode; up to a shop kiosk opens the shop (the DEALS kiosk at today's deal); up to
the VERIFY stand opens the card. The leaderboards' boards on the east side are filled from Net "Leaderboards" (the
same payload the 🏆 TOP panel shows), the portals' signs from Net "Population".

The camera: Roblox's own third person (Layout.lobby: CameraController steps aside), the mouse free.

  LobbyController.play(modeKey?, from?)   what PLAY, a card, the beacon and a portal do (Net "Play")
  LobbyController.counts()                the last Net "Population"
  LobbyController.state()                 { verified, parkourBest, running, startedAt, step, of }
  LobbyController.update()                one look at the world's zones (stepped on its own; tests call it)
  LobbyController.verifyOpen()            LobbyController.openVerify()   .closeVerify()
  LobbyController.refs                    the screen's pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local LobbyBuilder = require(ReplicatedStorage.Shared.World.LobbyBuilder)
local Modes = require(ReplicatedStorage.Shared.Data.Modes)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local LeaderboardController = require(script.Parent.LeaderboardController)
local PanelController = require(script.Parent.PanelController)

local LobbyController = { Name = "LobbyController", Order = 40, Modes = { "lobby" } }

local C = Theme.Color
local GOLD = Constants.GOLD
local player = Players.LocalPlayer
local refs = {}
LobbyController.refs = refs

-- The geometry (design pixels, on the 1240 x 560 canvas): the PLAY block at the bottom centre, the cards over it,
-- the toast over those; the SHOP button and the Shards at the top left (the 🏆 TOP button has the top right)
local G = {
	play = { w = 360, h = 88, bottom = 16 },
	card = { w = 150, h = 62, gap = 10 },
	toast = { w = 480, h = 32 },
	clock = { w = 300, h = 40, top = 12 },
	verify = { w = 440, h = 212 },
}
LobbyController.G = G
LobbyController.PLAY_COOLDOWN = 3 -- seconds between two "Play" sends (a dais stood on, a button mashed)
LobbyController.ZONE = { beacon = 8, portal = 5.5, kiosk = 7, verify = 7 } -- studs from each spot that count

local counts = {} -- [modeKey] = n (Net "Population")
local state = { verified = false, parkourBest = 0, running = false, step = 0, of = 4 }
local lastPlay = -math.huge
local toastToken

function LobbyController.counts()
	return counts
end

function LobbyController.state()
	return state
end

local function total()
	local n = 0
	for _, key in Modes.LIST do
		n += counts[key] or 0
	end
	return n
end

-- Toasts (the HUD isn't here: the lobby has its own line) ---------------------------------------------------------
local function toast(text, kind)
	local t = refs.toast
	if not t then
		return
	end
	if Layout.panel() and Layout.statusSink and Layout.statusSink(text, kind) then
		return -- (the shop's open: its own message line says it)
	end
	t.Text = string.gsub(text, " ?◆", " Shards")
	t.TextColor3 = kind == "bad" and C.red or (kind == "good" and C.good or C.ink)
	t.Visible = true
	local token = {}
	toastToken = token
	task.delay(3.5, function()
		if toastToken == token then
			t.Visible = false
		end
	end)
end
LobbyController.toast = toast

-- PLAY -----------------------------------------------------------------------------------------------------------
function LobbyController.play(key, from)
	if key ~= nil and not Modes[key] then
		key = nil
	end
	local now = os.clock()
	if now - lastPlay < LobbyController.PLAY_COOLDOWN then
		return false
	end
	lastPlay = now
	Bus.Tap:Fire("lobby_play_" .. (from or "button"))
	Net.send("Play", key)
	local m = key and Modes[key]
	toast(m and `Joining {m.name}…` or "Joining the fullest game…", "info")
	return true
end

local function paintCounts()
	for _, key in Modes.LIST do
		local card = refs.cards and refs.cards[key]
		if card then
			local n = counts[key] or 0
			card.Count.Text = n == 1 and "1 playing" or `{Format.num(n)} playing`
		end
	end
	if refs.playLine then
		local n = total()
		refs.playLine.Text = n > 0 and `joins the fullest game · {Format.num(n)} playing` or "joins the fullest game"
	end
	for key, sign in refs.portalSigns or {} do
		local m = Modes[key]
		local n = counts[key] or 0
		LobbyBuilder.sign(sign, string.upper(m and m.name or key), `{Format.num(n)} PLAYING`, m and m.color)
	end
end

-- The screen -------------------------------------------------------------------------------------------------------
local function buildPlay(gui)
	local b = Theme.button({
		Name = "Play",
		Text = "",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -G.play.bottom),
		Size = UDim2.fromOffset(G.play.w, G.play.h),
		Parent = gui,
	})
	b.Modal = true
	Theme.title({
		Name = "Head",
		Text = "▶  PLAY",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 2),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 40,
		Parent = b,
	})
	refs.playLine = Theme.text({
		Name = "Line",
		Text = "joins the fullest game",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 54),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		fit = 15,
		Parent = b,
	})
	b.Activated:Connect(function()
		LobbyController.play(nil, "button")
	end)
	refs.play = b
end

local function buildCards(gui)
	refs.cards = {}
	local y = G.play.bottom + G.play.h + G.card.gap
	for i, key in Modes.LIST do
		local m = Modes[key]
		local card = Theme.new("TextButton", {
			Name = "Card_" .. key,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, (i - (#Modes.LIST + 1) / 2) * (G.card.w + G.card.gap), 1, -y),
			Size = UDim2.fromOffset(G.card.w, G.card.h),
			BackgroundColor3 = C.paper,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = true,
			Modal = true,
			Parent = gui,
		}, { Theme.corner(6), Theme.stroke(2) })
		Theme.new("Frame", {
			Name = "Stripe",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = m.color,
			BorderSizePixel = 0,
			Parent = card,
		}, { Theme.corner(6) })
		Theme.text({
			Name = "Title",
			Text = string.upper(m.name),
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -20, 0, 28),
			Font = Theme.Display,
			fit = 16,
			Parent = card,
		})
		Theme.text({
			Name = "Count",
			Text = "0 playing",
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.new(1, -20, 0, 22),
			TextColor3 = C.muted,
			fit = 13,
			Parent = card,
		})
		card.Activated:Connect(function()
			LobbyController.play(key, "card")
		end)
		refs.cards[key] = card
	end
	refs.toast = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(y + G.card.h + G.card.gap)),
		Size = UDim2.fromOffset(G.toast.w, G.toast.h),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		fit = 17,
		outline = 2,
		TextColor3 = C.ink,
		Visible = false,
		Parent = gui,
	})
end

local function buildTop(gui)
	local shop = Theme.button({
		Name = "Shop",
		Text = "🛒 SHOP",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(130, 44),
		BackgroundColor3 = C.white,
		dark = true,
		Parent = gui,
	})
	shop.Modal = true
	shop.Activated:Connect(function()
		PanelController.open("shop", "lobby_button")
	end)
	refs.shop = shop
	local slab = Theme.slab({
		Name = "Shards",
		Position = UDim2.fromOffset(12, 62), -- (under SHOP: the PARTY chip has the spot beside it)
		Size = UDim2.fromOffset(130, 40),
		Parent = gui,
	})
	Theme.gem(slab, 22, { Name = "Gem", Position = UDim2.fromOffset(10, 11) })
	refs.shards = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -48, 1, -12),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 22,
		Parent = slab,
	})
	refs.shardsSlab = slab
	refs.clock = Theme.slab({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, G.clock.top),
		Size = UDim2.fromOffset(G.clock.w, G.clock.h),
		Visible = false,
		Parent = gui,
	})
	refs.clockText = Theme.text({
		Name = "Words",
		Text = "PARKOUR 0:00.0 · 0/4",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 1, -10),
		Font = Theme.Display,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 20,
		Parent = refs.clock,
	})
end

local function buildVerify(gui)
	local card = Theme.card({
		Name = "Verify",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(G.verify.w, G.verify.h),
		Visible = false,
		Parent = gui,
	})
	refs.verifyHead = Theme.title({
		Name = "Head",
		Text = "LIKE TURF WARS? 👍",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		fit = 28,
		Parent = card,
	})
	refs.verifyLine = Theme.text({
		Name = "Line",
		Text = "If you like the game, tap VERIFY to tell us.\nA thank-you: 100 Shards and the Supporter banner.",
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 17,
		Parent = card,
	})
	refs.verifyGo = Theme.button({
		Name = "VerifyButton",
		Text = "👍 VERIFY",
		Position = UDim2.fromOffset(32, 140),
		Size = UDim2.fromOffset(200, 54),
		BackgroundColor3 = GOLD,
		Modal = true,
		Parent = card,
	})
	refs.verifyLater = Theme.button({
		Name = "Later",
		Text = "LATER",
		Position = UDim2.fromOffset(G.verify.w - 32 - 160, 140),
		Size = UDim2.fromOffset(160, 54),
		BackgroundColor3 = C.white,
		dark = true,
		Modal = true,
		Parent = card,
	})
	refs.verifyGo.Activated:Connect(function()
		if state.verified then
			LobbyController.closeVerify()
			return
		end
		Bus.Tap:Fire("verify")
		Net.send("Verify")
		refs.verifyGo.Text = "SENT 👍" -- (the server's "verified" paints the thanks)
	end)
	refs.verifyLater.Activated:Connect(LobbyController.closeVerify)
	refs.verify = card
end

local function paintVerify()
	if not refs.verify then
		return
	end
	if state.verified then
		refs.verifyHead.Text = "THANKS, SUPPORTER! 👍"
		refs.verifyLine.Text = "You're verified: the Supporter banner is yours.\nThank you for playing Turf Wars."
		refs.verifyGo.Text = "YOU'RE VERIFIED ✓"
		refs.verifyLater.Text = "CLOSE"
	end
	local sign = refs.verifySign
	if sign then
		if state.verified then
			LobbyBuilder.sign(sign, "VERIFIED ✓", "THANKS, SUPPORTER!", C.good)
		else
			LobbyBuilder.sign(sign, "VERIFY 👍", "LIKE TURF WARS?")
		end
	end
end

function LobbyController.verifyOpen()
	return refs.verify ~= nil and refs.verify.Visible == true
end

function LobbyController.openVerify()
	if not refs.verify then
		return
	end
	paintVerify()
	refs.verify.Visible = true
	Layout.modal("verify", refs.verify)
	Theme.pop(refs.verify)
end

function LobbyController.closeVerify()
	if refs.verify then
		refs.verify.Visible = false
	end
end

local function paintShards()
	local p = Store.get("profile")
	if refs.shards and p then
		refs.shards.Text = Theme.commas(p.shards or 0)
	end
end

-- The parkour clock
local function paintClock()
	if not refs.clock then
		return
	end
	refs.clock.Visible = state.running == true
	if state.running and state.startedAt then
		local t = os.clock() - state.startedAt
		refs.clockText.Text =
			`PARKOUR {math.floor(t / 60)}:{string.format("%04.1f", t % 60)} · {state.step}/{state.of}`
	end
end

-- The world ----------------------------------------------------------------------------------------------------------
local zones = {} -- { key, pos, radius, enter = fn, inside = bool }
local lobbyFolder

local function prompt(part, action, object, fn)
	local p = Instance.new("ProximityPrompt")
	p.Name = "LobbyPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.ClickablePrompt = true
	p.Parent = part
	p.Triggered:Connect(fn)
	return p
end

local function openKiosk(tab, hint)
	if PanelController.isOpen() then
		return
	end
	Bus.Tap:Fire("lobby_kiosk_" .. string.lower(string.gsub(hint or "", "%s", "")))
	if tab == "deal" then
		PanelController.showDeal("lobby_kiosk")
	else
		PanelController.open("shop", "lobby_kiosk")
	end
end

-- The boards: a SurfaceGui each with the board's name and its top ten (gold, silver, bronze on the first three)
local function paintBoards()
	local s = LeaderboardController.state()
	if not s or not refs.boards then
		return
	end
	local NAME = { wins = "WINS", kills = "KILLS", mvps = "MVPS", streak = "BEST STREAK" }
	for key, board in refs.boards do
		local gui = board:FindFirstChild("Rows")
		if not gui then
			gui = Instance.new("SurfaceGui")
			gui.Name = "Rows"
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			Theme.new("TextLabel", {
				Name = "Title",
				BackgroundColor3 = C.ink,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 0.12),
				Font = Theme.Display,
				TextScaled = true,
				TextColor3 = GOLD,
				Text = NAME[key] or string.upper(key),
				Parent = gui,
			})
			for i = 1, 10 do
				local row = Theme.new("TextLabel", {
					Name = "Row" .. i,
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.04, 0.13 + (i - 1) * 0.086),
					Size = UDim2.fromScale(0.92, 0.08),
					Font = Theme.Body,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = C.ink,
					Text = "",
					Parent = gui,
				})
				local medal = LeaderboardController.MEDAL[i]
				if medal then
					row.TextColor3 = medal[1]
				end
			end
			gui.Parent = board
		end
		local rows = s.boards[key] or {}
		for i = 1, 10 do
			local r = rows[i]
			local row = gui:FindFirstChild("Row" .. i)
			if row then
				row.Text = r and `{i}. {r.name}  {Format.num(r.value)}`
					or (i == 1 and "No one yet: be the first!" or "")
			end
		end
	end
end

local function find()
	local folder = workspace:FindFirstChild("Lobby")
	if folder == lobbyFolder then
		return
	end
	lobbyFolder = folder
	table.clear(zones)
	refs.boards, refs.portalSigns, refs.verifySign = {}, {}, nil
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local name = d.Name
		if name == "PlayBeacon" then
			table.insert(zones, {
				key = "beacon",
				pos = d.Position,
				radius = LobbyController.ZONE.beacon,
				enter = function()
					LobbyController.play(nil, "beacon")
				end,
			})
			prompt(d, "Play", "▶ PLAY", function()
				LobbyController.play(nil, "beacon")
			end)
		elseif name == "Portal" then
			local key = d:GetAttribute("Mode")
			table.insert(zones, {
				key = "portal_" .. tostring(key),
				pos = d.Position + Vector3.new(0, 0, 3),
				radius = LobbyController.ZONE.portal,
				enter = function()
					LobbyController.play(key, "portal")
				end,
			})
		elseif name == "PortalSign" then
			refs.portalSigns[d:GetAttribute("Mode")] = d
		elseif name == "ShopKiosk" then
			local tab, hint = d:GetAttribute("Tab"), d:GetAttribute("Hint")
			table.insert(zones, {
				key = "kiosk_" .. tostring(hint),
				pos = d.Position,
				radius = LobbyController.ZONE.kiosk,
				enter = function()
					openKiosk(tab, hint)
				end,
			})
			prompt(d, "Open Shop", "🛒 " .. tostring(hint), function()
				openKiosk(tab, hint)
			end)
		elseif name == "VerifyStand" and not refs.verifyZone then
			refs.verifyZone = true
			table.insert(zones, {
				key = "verify",
				pos = d.Position,
				radius = LobbyController.ZONE.verify,
				enter = LobbyController.openVerify,
			})
			prompt(d, "Verify", "👍 VERIFY", LobbyController.openVerify)
		elseif name == "VerifySign" then
			refs.verifySign = d
		elseif name == "LobbyBoard" then
			refs.boards[d:GetAttribute("Board")] = d
		end
	end
	refs.verifyZone = nil
	paintCounts()
	paintVerify()
	paintBoards()
end

-- One look at where you stand: a zone entered does its thing once, and again only after you've left it
function LobbyController.update()
	find()
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then
		return
	end
	local pos = r.Position
	for _, z in zones do
		local inside = LobbyBuilder.near(pos, z.pos, z.radius, 8)
		if inside and not z.inside then
			z.inside = true
			z.enter()
		elseif not inside and z.inside and not LobbyBuilder.near(pos, z.pos, z.radius + 2, 8) then
			z.inside = false
		end
	end
end

function LobbyController.zones()
	return zones
end

-- The camera: Roblox's own third person, the mouse free
local function camera()
	Layout.lobby(true)
	pcall(function()
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 6
		player.CameraMaxZoomDistance = 22
	end)
	pcall(function()
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

function LobbyController:init()
	local gui = Theme.screen("Lobby", 6, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	camera()
	buildPlay(gui)
	buildCards(gui)
	buildTop(gui)
	buildVerify(gui)
	paintCounts()
	paintShards()
	Store.Changed:Connect(function(partial)
		if partial.profile then
			paintShards()
		end
	end)
	Net.listen("Population", function(p)
		if type(p) ~= "table" then
			return
		end
		for _, key in Modes.LIST do
			counts[key] = math.max(0, math.floor(tonumber(p[key]) or 0))
		end
		paintCounts()
	end)
	Net.listen("Lobby", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.kind == "state" then
			state.verified = m.verified == true
			state.parkourBest = m.parkourBest or 0
			state.of = m.of or state.of
			paintVerify()
		elseif m.kind == "verified" then
			state.verified = true
			paintVerify()
		elseif m.kind == "parkour" then
			state.step = m.step or 0
			state.of = m.of or state.of
			if m.go then
				state.running = true
				state.startedAt = os.clock()
				toast("GO! Climb to the top of the tower", "good")
			elseif m.done then
				state.running = false
				state.parkourBest = m.best or state.parkourBest
				refs.clockText.Text = `PARKOUR DONE · {m.seconds or 0}s`
			elseif m.fell then
				state.running = false
				toast("Parkour: back to the start", "info")
			else
				state.startedAt = os.clock() - (m.seconds or 0) -- (the server's clock is the one that counts)
				toast(`CHECKPOINT {m.step}/{m.of}`, "good")
			end
			paintClock()
		end
	end)
	Net.listen("Toast", toast)
	Net.listen("Earned", function(e)
		if refs.shards and type(e) == "table" and e.total then
			refs.shards.Text = Theme.commas(e.total)
		end
	end)
	Net.listen("Unlock", function(u)
		if type(u) ~= "table" then
			return
		end
		local s = u.step or {}
		toast(
			u.title and `{u.title} {u.line or s.name or ""}` or `NEW {string.upper(s.kind or "")}: {s.name or ""}`,
			"good"
		)
	end)
	Net.listen("Leaderboards", function()
		task.defer(paintBoards) -- (LeaderboardController keeps the payload; it heard it first)
	end)
	task.delay(1, function()
		pcall(Net.send, "Top")
	end)
	-- (Esc closes the card)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and LobbyController.verifyOpen() then
			LobbyController.closeVerify()
		end
	end)
	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if state.running then
			paintClock()
		end
		if t < nextAt then
			return
		end
		nextAt = t + 0.2
		LobbyController.update()
	end)
end

return LobbyController

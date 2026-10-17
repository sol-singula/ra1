--[[
The leaderboards on screen (LeaderboardService has the numbers), in the SUPERHOT look:

  🏆 TOP (L)    a small white button in the top right corner, above the kill feed
  the panel     four tabs (WINS, KILLS, MVP, STREAK) and ALL TIME / THIS SERVER; a row each: the rank, the name,
                the number. The top three are tinted gold, silver and bronze; your row is black. Under the list
                where you stand ("YOU  #12 · 34 WINS"). While it's open the mouse is free (Layout.setPanel and a
                Modal close button); Esc or ✕ closes it, and it's one panel at a time (Layout.claimPanel).
  gamepad       D-pad up opens and closes it, LB / RB change the tab, Y flips ALL TIME / THIS SERVER, B closes
  touch         a tap on the button; the list scrolls

Opening asks the server (Net "Top"); the answer (Net "Leaderboards") comes again after each refresh and match.

  LeaderboardController.open(tab?, scope?)  .close()  .toggle()  .isOpen()  .tab()  .scope()  .refresh()
  LeaderboardController.state()   the server's last payload
  LeaderboardController.refs      LeaderboardController.BTN  .P
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local Device = require(script.Parent.Parent.UI.Device)

local LeaderboardController = { Name = "LeaderboardController", Order = 49 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
LeaderboardController.refs = refs

-- The geometry (design pixels): the button in the top right corner (the kill feed starts under it, at y 56); the
-- panel in the middle, the party panel's size, under the top bar
local BTN = { w = 120, h = 36, right = 12, top = 12 }
local P = { w = 440, h = 400, top = 96, listY = 140, listH = 216, row = 26, gap = 2 }
LeaderboardController.BTN = BTN
LeaderboardController.P = P

local TABS = {
	{ "wins", "WINS", "WINS" },
	{ "kills", "KILLS", "KILLS" },
	{ "mvps", "MVP", "MVPS" },
	{ "streak", "STREAK", "BEST STREAK" },
}
local MEDAL = { -- the badge, and the row's pale tint
	{ Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 244, 205) },
	{ Color3.fromRGB(176, 180, 188), Color3.fromRGB(236, 238, 242) },
	{ Color3.fromRGB(205, 127, 50), Color3.fromRGB(246, 224, 202) },
}
LeaderboardController.MEDAL = MEDAL

local current, scope = "wins", "all" -- scope: "all" (all time) | "server"
local state -- the server's last Leaderboards payload

local function text(parent, props)
	props.Parent = parent
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
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

-- a picked button is black with white letters, the others white
local function paint(b, on)
	b.BackgroundColor3 = on and C.ink or C.white
	b.Label.TextColor3 = on and C.white or C.ink
end

local function info(key)
	for _, t in TABS do
		if t[1] == key then
			return t
		end
	end
	return TABS[1]
end

function LeaderboardController.state()
	return state
end

function LeaderboardController.tab()
	return current
end

function LeaderboardController.scope()
	return scope
end

function LeaderboardController.isOpen()
	return refs.panel ~= nil and refs.panel.Visible == true
end

-- The list -----------------------------------------------------------------------------------------------------
local function clear(frame)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function addRow(list, i, r)
	local you = r.userId == player.UserId
	local medal = MEDAL[r.rank]
	local row = Theme.new("Frame", {
		Name = "Row" .. i,
		Position = UDim2.fromOffset(0, (i - 1) * (P.row + P.gap)),
		Size = UDim2.fromOffset(P.w - 34, P.row),
		BackgroundColor3 = you and C.ink or (medal and medal[2] or C.white),
		BorderSizePixel = 0,
		Parent = list,
	}, { Theme.corner(3) })
	row:SetAttribute("UserId", r.userId)
	local badge = Theme.new("Frame", {
		Name = "Rank",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(40, P.row - 6),
		BackgroundColor3 = medal and medal[1] or (you and C.white or C.ink),
		BorderSizePixel = 0,
		Parent = row,
	}, { Theme.corner(3) })
	text(badge, {
		Name = "Num",
		Text = tostring(r.rank),
		Size = UDim2.new(1, -4, 1, -2),
		Position = UDim2.fromOffset(2, 1),
		fit = 14,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = (medal or you) and C.ink or C.white,
	})
	text(row, {
		Name = "Who",
		Text = tostring(r.name or "?") .. (you and "  (you)" or ""),
		Size = UDim2.fromOffset(P.w - 34 - 140, P.row - 6),
		Position = UDim2.fromOffset(50, 3),
		fit = 14,
		TextColor3 = you and C.white or C.ink,
	})
	text(row, {
		Name = "Value",
		Text = tostring(r.value or 0),
		Size = UDim2.fromOffset(76, P.row - 6),
		Position = UDim2.fromOffset(P.w - 34 - 82, 3),
		fit = 15,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = you and C.white or C.ink,
	})
	return row
end

local function ago(at)
	local s = math.max(0, os.time() - (at or 0))
	if s < 60 then
		return "just now"
	end
	return `{s // 60} min ago`
end

function LeaderboardController.refresh()
	if not refs.panel then
		return
	end
	local t = info(current)
	for _, spec in TABS do
		paint(refs.tabs[spec[1]], spec[1] == current)
	end
	paint(refs.all, scope == "all")
	paint(refs.server, scope == "server")
	refs.valueHead.Text = t[3]
	local list = refs.list
	clear(list)
	local rows = state and (scope == "all" and state.boards or state.server)
	rows = rows and rows[current] or {}
	for i, r in rows do
		addRow(list, i, r)
	end
	list.CanvasSize = UDim2.fromOffset(0, #rows * (P.row + P.gap))
	list.CanvasPosition = Vector2.new(0, 0)
	-- an empty board says why
	local empty = ""
	if not state then
		empty = "Loading..."
	elseif #rows == 0 and scope == "all" and not state.ok then
		empty = "The all-time boards can't be reached right now. THIS SERVER still works."
	elseif #rows == 0 then
		empty = "Nobody on this board yet. Play a match and be the first!"
	end
	refs.empty = empty ~= ""
			and text(list, {
				Name = "Empty",
				Text = empty,
				Size = UDim2.fromOffset(P.w - 60, 40),
				Position = UDim2.fromOffset(20, 20),
				fit = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = C.muted,
			})
		or nil
	-- where you stand
	local you = state and state.you and state.you[current]
	local word = string.lower(t[3])
	if not you then
		refs.you.Text = ""
	elseif scope == "all" then
		local where = you.rank and `#{you.rank}` or "not in the top 50 yet"
		refs.you.Text = `YOU  {where}  ·  {you.value or 0} {word}`
	else
		local where = you.serverRank and `#{you.serverRank} here` or "watching"
		refs.you.Text = `YOU  {where}  ·  {you.value or 0} {word}`
	end
	refs.updated.Text = (scope == "all" and state and state.ok) and `Updated {ago(state.at)}`
		or (scope == "server" and "Live, everyone in this server" or "")
end

-- Open, close ---------------------------------------------------------------------------------------------------
function LeaderboardController.open(tab, sc)
	if not refs.panel then
		return
	end
	current = (tab and info(tab)[1] == tab) and tab or current
	scope = (sc == "all" or sc == "server") and sc or scope
	if not LeaderboardController.isOpen() then
		Layout.claimPanel("top", LeaderboardController.close)
		refs.panel.Visible = true
		Layout.modal("top", refs.panel)
		Layout.setPanel(true)
		Theme.pop(refs.panel)
		Net.send("Top")
		if Device.kind() == "gamepad" then
			pcall(function()
				GuiService.SelectedObject = refs.tabs[current]
			end)
		end
	end
	LeaderboardController.refresh()
end

function LeaderboardController.close()
	if not LeaderboardController.isOpen() then
		return
	end
	refs.panel.Visible = false
	pcall(function()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(refs.panel) then
			GuiService.SelectedObject = nil
		end
	end)
	-- (the mouse goes back to the camera, unless another panel took over)
	local ok, Panel = pcall(require, script.Parent.PanelController)
	local ok2, Party = pcall(require, script.Parent.PartyController)
	if not ((ok and Panel.isOpen()) or (ok2 and Party.isOpen())) then
		Layout.setPanel(false)
	end
end

function LeaderboardController.toggle()
	if LeaderboardController.isOpen() then
		LeaderboardController.close()
	else
		LeaderboardController.open()
	end
end

local function step(by)
	for i, t in TABS do
		if t[1] == current then
			LeaderboardController.open(TABS[(i - 1 + by) % #TABS + 1][1])
			return
		end
	end
end

-- Build --------------------------------------------------------------------------------------------------------
local function buildButton(gui)
	local b = Theme.new("TextButton", {
		Name = "TopButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -BTN.right, 0, BTN.top),
		Size = UDim2.fromOffset(BTN.w, BTN.h),
		BackgroundColor3 = C.white,
		Text = "",
		AutoButtonColor = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	refs.buttonHead = Theme.title({
		Name = "Head",
		Text = "🏆 TOP  [L]",
		Size = UDim2.new(1, -12, 1, -10),
		Position = UDim2.fromOffset(6, 5),
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = false,
		Parent = b,
	})
	b.Activated:Connect(function()
		LeaderboardController.toggle()
	end)
	refs.button = b
end

local function hint()
	if refs.buttonHead then
		local kind = Device.kind()
		refs.buttonHead.Text = kind == "touch" and "🏆 TOP"
			or (kind == "gamepad" and "🏆 TOP  [↑]" or "🏆 TOP  [L]")
	end
end

local function buildPanel(gui)
	local panel = Theme.card({
		Name = "TopPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, P.top),
		Size = UDim2.fromOffset(P.w, P.h),
		BackgroundColor3 = C.white,
		Visible = false,
		Parent = gui,
	})
	refs.panel = panel
	refs.title = Theme.title({
		Name = "Title",
		Text = "🏆 LEADERBOARDS",
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(12, 8),
		TextColor3 = C.ink,
		outline = false,
		Parent = panel,
	})
	refs.close = button(panel, "Close", "✕", P.w - 52, 6, 42, 32, true, function()
		LeaderboardController.close()
	end)
	refs.close.Modal = true -- (frees the mouse from first person while the panel is up)
	refs.tabs = {}
	local tw = (P.w - 20 - 3 * 6) / 4
	for i, t in TABS do
		refs.tabs[t[1]] = button(panel, "Tab_" .. t[1], t[2], 10 + (i - 1) * (tw + 6), 46, tw, 32, false, function()
			LeaderboardController.open(t[1])
		end)
	end
	local sw = (P.w - 20 - 6) / 2
	refs.all = button(panel, "AllTime", "ALL TIME", 10, 84, sw, 28, false, function()
		LeaderboardController.open(nil, "all")
	end)
	refs.server = button(panel, "ThisServer", "THIS SERVER", 16 + sw, 84, sw, 28, false, function()
		LeaderboardController.open(nil, "server")
	end)
	text(panel, {
		Name = "RankHead",
		Text = "#",
		Size = UDim2.fromOffset(40, 18),
		Position = UDim2.fromOffset(13, 118),
		fit = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
	})
	text(panel, {
		Name = "NameHead",
		Text = "PLAYER",
		Size = UDim2.fromOffset(200, 18),
		Position = UDim2.fromOffset(60, 118),
		fit = 12,
		TextColor3 = C.muted,
	})
	refs.valueHead = text(panel, {
		Name = "ValueHead",
		Text = "WINS",
		Size = UDim2.fromOffset(120, 18),
		Position = UDim2.fromOffset(P.w - 150, 118), -- (its right edge on the rows' numbers')
		fit = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.muted,
	})
	refs.list = Theme.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(10, P.listY),
		Size = UDim2.fromOffset(P.w - 20, P.listH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	refs.you = text(panel, {
		Name = "You",
		Text = "",
		Size = UDim2.fromOffset(P.w - 20, 20),
		Position = UDim2.fromOffset(10, P.listY + P.listH + 4),
		fit = 15,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	refs.updated = text(panel, {
		Name = "Updated",
		Text = "",
		Size = UDim2.fromOffset(P.w - 20, 16),
		Position = UDim2.fromOffset(10, P.listY + P.listH + 26),
		fit = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
	})
end

function LeaderboardController:init()
	local gui = Theme.screen("Top", 16, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildButton(gui)
	buildPanel(gui)
	hint()
	Device.Changed:Connect(hint)
	Net.listen("Leaderboards", function(s)
		if type(s) ~= "table" or type(s.boards) ~= "table" or type(s.server) ~= "table" then
			return
		end
		state = s
		if LeaderboardController.isOpen() then
			LeaderboardController.refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		local open = LeaderboardController.isOpen()
		-- (the pad's B also crouches: while the panel is up it closes it, whoever saw it first)
		if open and (key == Enum.KeyCode.ButtonB or (key == Enum.KeyCode.Escape and not processed)) then
			LeaderboardController.close()
			return
		end
		if processed then
			return
		end
		if key == Enum.KeyCode.L or key == Enum.KeyCode.DPadUp then
			LeaderboardController.toggle()
		elseif open and key == Enum.KeyCode.ButtonL1 then
			step(-1)
		elseif open and key == Enum.KeyCode.ButtonR1 then
			step(1)
		elseif open and key == Enum.KeyCode.ButtonY then
			LeaderboardController.open(nil, scope == "all" and "server" or "all")
		end
	end)
	-- the tutorial: the button steps aside while it guides and during its cinematics
	local last = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t - last < 0.25 then
			return
		end
		last = t
		local away = Layout.focused() or Layout.inCinema()
		refs.button.Visible = not away
		if away and LeaderboardController.isOpen() then
			LeaderboardController.close()
		end
	end)
end

return LeaderboardController

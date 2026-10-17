--[[
Parties on screen (PartyService decides everything), in the SUPERHOT look:

  PARTY (P)     a small white button at the top left, beside INVITE: opens the party panel; its line says
                "Play together" or "2/4 · you lead"
  the panel     your party (★ the leader; KICK for the leader), the players in this server with INVITE, and
                LEAVE · FIND A NEW SERVER · JOIN A FULLER SERVER (the last two for the leader). While it's open the
                mouse is free (Layout.setPanel). Esc or ✕ closes it; it steps aside for the shop panel.
  the list      in the left corner while you're in a party: "👥 PARTY" and the names (under SHOP; on a phone
                under the health bar)
  the card      "NAME WANTS YOU IN THEIR PARTY" / "PARTY UP WITH NAME?": YES / NO (Y / N), gone after 20 s.
                Out of the fight it frees the mouse (a question card, Layout.modal); in the fight it doesn't, so
                your aim stays: answer with Y / N.
  the marker    👥 over each party member's head, seen only by the party (a BillboardGui in your own PlayerGui)

  PartyController.open()  .close()  .toggle()  .isOpen()  .refresh()  .state()  .marks()
  PartyController.showInvite(inv)  .card()  .answer(yes)  .refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)
local Device = require(script.Parent.Parent.UI.Device)

local PartyController = { Name = "PartyController", Order = 49 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
PartyController.refs = refs
local party -- what the server sent: { id, leader, max, members = { { userId, name } } } or nil
local invite -- { from, name, kind, seconds, ends }
-- The geometry (design pixels): the button right of INVITE (16..216), clear of the top bar (from x 340); the list
-- under SHOP (ends at y 124), or on a phone under the health bar (y 134..178); the card under the list's room.
local BTN = { x = 224, y = 16, w = 104, h = 50 }
local LIST = { x = 16, desk = 132, touch = 186, w = 200, head = 22, row = 18 }
local CARD = { x = 16, y = 300, w = 300, h = 112 }
local P = { w = 440, h = 400, top = 96 }

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

function PartyController.state()
	return party
end

local function isLeader()
	return party ~= nil and party.leader == player.UserId
end

local function inParty(userId)
	for _, m in party and party.members or {} do
		if m.userId == userId then
			return true
		end
	end
	return false
end

local function teamColor()
	return Constants.TEAM_COLOR[Store.team() or ""] or C.ink
end

-- The PARTY button and the corner list ---------------------------------------------------------------------------
local function buildButton(gui)
	local b = Theme.new("TextButton", {
		Name = "PartyButton",
		Position = UDim2.fromOffset(BTN.x, BTN.y),
		Size = UDim2.fromOffset(BTN.w, BTN.h),
		BackgroundColor3 = C.white,
		Text = "",
		AutoButtonColor = true,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	refs.buttonHead = Theme.title({
		Name = "Head",
		Text = "🤝 PARTY",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 5),
		TextColor3 = C.ink,
		outline = false,
		Parent = b,
	})
	refs.buttonLine = text(b, {
		Name = "Line",
		Text = "Play together",
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.fromOffset(6, 28),
		fit = 12,
		TextColor3 = C.muted,
	})
	b.Activated:Connect(function()
		PartyController.toggle()
	end)
	refs.button = b
	refs.list = Theme.new("Frame", {
		Name = "PartyList",
		Position = UDim2.fromOffset(LIST.x, LIST.desk),
		Size = UDim2.fromOffset(LIST.w, LIST.head),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
end

local function placeList()
	if refs.list then
		local y = Device.isTouch() and LIST.touch or LIST.desk
		refs.list.Position = UDim2.fromOffset(LIST.x, y)
	end
end

local function refreshList()
	local list = refs.list
	if not list then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local n = party and #party.members or 0
	list.Visible = n >= 2
	refs.buttonLine.Text = n >= 2 and (`{n}/{party.max or 4}` .. (isLeader() and " · you lead" or " in party"))
		or "Play together"
	if n < 2 then
		return
	end
	list.Size = UDim2.fromOffset(LIST.w, LIST.head + n * LIST.row + 4)
	Theme.title({
		Name = "Head",
		Text = "👥 PARTY",
		Size = UDim2.new(1, -12, 0, LIST.head - 4),
		Position = UDim2.fromOffset(6, 3),
		TextColor3 = teamColor(),
		outline = false,
		Parent = list,
	})
	for i, m in party.members do
		text(list, {
			Name = "Member" .. i,
			Text = (m.userId == party.leader and "★ " or "   ")
				.. m.name
				.. (m.userId == player.UserId and " (you)" or ""),
			Size = UDim2.new(1, -12, 0, LIST.row - 2),
			Position = UDim2.fromOffset(6, LIST.head + (i - 1) * LIST.row),
			fit = 13,
		})
	end
end

-- The 👥 marker over party members (only this client draws it) ----------------------------------------------------
local marks = {} -- [userId] = BillboardGui

local function refreshMarks()
	local want = {}
	for _, m in party and party.members or {} do
		if m.userId ~= player.UserId then
			want[m.userId] = true
		end
	end
	for id, bb in marks do
		if not want[id] then
			bb:Destroy()
			marks[id] = nil
		end
	end
	local pg = player:FindFirstChild("PlayerGui")
	for id in want do
		local other = Players:GetPlayerByUserId(id)
		local c = other and other.Character
		local head = c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
		local bb = marks[id]
		if not bb or not bb.Parent then
			bb = Theme.new("BillboardGui", {
				Name = "PartyMark",
				Size = UDim2.fromOffset(34, 34),
				StudsOffset = Vector3.new(0, 2.6, 0),
				AlwaysOnTop = true,
				LightInfluence = 0,
				MaxDistance = 400,
				Parent = pg,
			})
			Theme.text({
				Name = "Icon",
				Text = "👥",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = bb,
			})
			marks[id] = bb
		end
		bb.Adornee = head
		bb.Enabled = head ~= nil
	end
end

function PartyController.marks()
	return marks
end

-- The panel ----------------------------------------------------------------------------------------------------
function PartyController.isOpen()
	return refs.panel ~= nil and refs.panel.Visible == true
end

local function clear(frame)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function PartyController.refresh()
	local panel = refs.panel
	if not panel then
		return
	end
	local n = party and #party.members or 1
	refs.title.Text = party and `👥 YOUR PARTY {n}/{party.max or 4}` or "👥 PARTY"
	-- the members
	local box = refs.members
	clear(box)
	local rows = party and party.members or { { userId = player.UserId, name = player.DisplayName } }
	for i, m in rows do
		local y = (i - 1) * 30
		text(box, {
			Name = "Name" .. i,
			Text = (party and m.userId == party.leader and "★ " or "")
				.. m.name
				.. (m.userId == player.UserId and " (you)" or ""),
			Size = UDim2.fromOffset(300, 24),
			Position = UDim2.fromOffset(4, y + 3),
			fit = 15,
		})
		if isLeader() and m.userId ~= player.UserId then
			button(box, "Kick" .. i, "KICK", 330, y, 80, 28, false, function()
				Net.send("Party", "kick", m.userId)
			end)
		end
	end
	if not party then
		text(box, {
			Name = "Hint",
			Text = "Invite players below. A party plays on the same team.",
			Size = UDim2.fromOffset(410, 24),
			Position = UDim2.fromOffset(4, 33),
			fit = 13,
			TextColor3 = C.muted,
		})
	end
	-- everyone else in this server
	local list = refs.players
	clear(list)
	local y = 0
	local full = party and n >= (party.max or 4)
	for _, p in Players:GetPlayers() do
		if p ~= player and not inParty(p.UserId) then
			text(list, {
				Name = "Player_" .. p.UserId,
				Text = p.DisplayName .. (p:GetAttribute("Party") and "  · in a party" or ""),
				Size = UDim2.fromOffset(300, 24),
				Position = UDim2.fromOffset(4, y + 3),
				fit = 14,
			})
			if not full then
				button(list, "Invite_" .. p.UserId, "INVITE", 320, y, 84, 28, true, function()
					Net.send("Party", "invite", p.UserId)
				end)
			end
			y += 32
		end
	end
	if y == 0 then
		text(list, {
			Name = "Nobody",
			Text = "Nobody else is here yet. Use INVITE A FRIEND!",
			Size = UDim2.fromOffset(400, 24),
			Position = UDim2.fromOffset(4, 3),
			fit = 13,
			TextColor3 = C.muted,
		})
		y = 30
	end
	list.CanvasSize = UDim2.fromOffset(0, y)
	refs.inviteHead.Text = full and "YOUR PARTY IS FULL" or "INVITE SOMEONE IN THIS SERVER"
	-- the actions
	refs.leave.Visible = party ~= nil
	refs.newServer.Visible = isLeader()
	refs.fuller.Visible = isLeader()
end

local function buildPanel(gui)
	local panel = Theme.card({
		Name = "PartyPanel",
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
		Text = "👥 PARTY",
		Size = UDim2.fromOffset(360, 30),
		Position = UDim2.fromOffset(12, 8),
		TextColor3 = C.ink,
		outline = false,
		Parent = panel,
	})
	refs.close = button(panel, "Close", "✕", P.w - 52, 6, 42, 32, true, function()
		PartyController.close()
	end)
	refs.close.Modal = true -- (frees the mouse from first person while the panel is up)
	refs.members = Theme.new("Frame", {
		Name = "Members",
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.fromOffset(P.w - 20, 120),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	refs.inviteHead = text(panel, {
		Name = "InviteHead",
		Text = "INVITE SOMEONE IN THIS SERVER",
		Size = UDim2.fromOffset(P.w - 20, 20),
		Position = UDim2.fromOffset(10, 172),
		fit = 14,
		Font = Theme.Display,
	})
	refs.players = Theme.new("ScrollingFrame", {
		Name = "Players",
		Position = UDim2.fromOffset(10, 196),
		Size = UDim2.fromOffset(P.w - 20, 140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	refs.leave = button(panel, "Leave", "LEAVE PARTY", 10, 346, 120, 44, false, function()
		Net.send("Party", "leave")
	end)
	refs.newServer = button(panel, "NewServer", "FIND A NEW SERVER", 138, 346, 142, 44, true, function()
		Net.send("Party", "move", "new")
	end)
	refs.fuller = button(panel, "Fuller", "JOIN A FULLER SERVER", 288, 346, 142, 44, true, function()
		Net.send("Party", "move", "fuller")
	end)
end

function PartyController.open()
	if not refs.panel then
		return
	end
	local ok, Panel = pcall(require, script.Parent.PanelController)
	if ok and Panel.isOpen() then
		Panel.close() -- (one panel at a time)
	end
	refs.panel.Visible = true
	Layout.setPanel(true)
	PartyController.refresh()
	Theme.pop(refs.panel)
end

function PartyController.close()
	if not PartyController.isOpen() then
		return
	end
	refs.panel.Visible = false
	local ok, Panel = pcall(require, script.Parent.PanelController)
	if not (ok and Panel.isOpen()) then
		Layout.setPanel(false)
	end
end

function PartyController.toggle()
	if PartyController.isOpen() then
		PartyController.close()
	else
		PartyController.open()
	end
end

-- The invite card --------------------------------------------------------------------------------------------
local function closeCard()
	if refs.card then
		refs.card:Destroy()
		refs.card = nil
	end
	invite = nil
end

function PartyController.card()
	return refs.card, invite
end

function PartyController.answer(yes)
	if not invite then
		return false
	end
	Net.send("Party", yes and "accept" or "decline")
	closeCard()
	return true
end

function PartyController.showInvite(inv)
	closeCard()
	invite =
		{ from = inv.from, name = tostring(inv.name or "?"), kind = inv.kind, ends = os.clock() + (inv.seconds or 20) }
	local fight = Store.phase() == "fight"
	local card = Theme.card({
		Name = "PartyAsk",
		Position = UDim2.fromOffset(CARD.x, CARD.y),
		Size = UDim2.fromOffset(CARD.w, CARD.h),
		BackgroundColor3 = C.white,
		Parent = refs.gui,
	})
	refs.card = card
	if not fight then
		Layout.modal("party", card) -- (frees the mouse; in the fight your aim stays and Y / N answer)
	end
	Theme.title({
		Name = "Title",
		Text = invite.kind == "friend" and `PARTY UP WITH {string.upper(invite.name)}?`
			or `{string.upper(invite.name)} WANTS YOU IN THEIR PARTY`,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Parent = card,
	})
	refs.cardLine = text(card, {
		Name = "Line",
		Text = "Play on the same team!",
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 36),
		fit = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
	})
	local touch = Device.isTouch()
	local yes = button(card, "Yes", touch and "YES 👍" or "YES 👍  [Y]", 14, 60, 130, 40, true, function()
		PartyController.answer(true)
	end)
	local no = button(card, "No", touch and "NO" or "NO  [N]", CARD.w - 144, 60, 130, 40, false, function()
		PartyController.answer(false)
	end)
	yes.Modal, no.Modal = not fight, not fight
	Theme.pop(card)
	return card
end

-- Start ------------------------------------------------------------------------------------------------------
function PartyController:init()
	local gui = Theme.screen("Party", 16, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	buildButton(gui)
	buildPanel(gui)
	placeList()
	Device.Changed:Connect(placeList)
	Net.listen("PartyState", function(s)
		party = type(s) == "table" and type(s.members) == "table" and s or nil
		refreshList()
		refreshMarks()
		if PartyController.isOpen() then
			PartyController.refresh()
		end
	end)
	Net.listen("PartyInvite", function(inv)
		if type(inv) ~= "table" then
			return
		end
		if inv.cancel then
			closeCard()
		else
			PartyController.showInvite(inv)
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.me and party then
			refreshList() -- (the list's title in your team's colour)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if PartyController.isOpen() then
			PartyController.refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if PartyController.isOpen() then
				PartyController.refresh()
			end
		end)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.P then
			PartyController.toggle()
		elseif key == Enum.KeyCode.Escape and PartyController.isOpen() then
			PartyController.close()
		elseif invite and (key == Enum.KeyCode.Y or key == Enum.KeyCode.N) then
			-- (the winners' question card takes Y / N first while it's up)
			local ok, Feedback = pcall(require, script.Parent.FeedbackController)
			if not (ok and Feedback.current()) then
				PartyController.answer(key == Enum.KeyCode.Y)
			end
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t - last < 0.5 then
			return
		end
		last = t
		if invite then
			local left = math.ceil(invite.ends - t)
			if left <= 0 then
				closeCard()
			elseif refs.cardLine then
				refs.cardLine.Text = `Play on the same team! ({left} s)`
			end
		end
		-- the shop panel opened over this one: step aside
		local ok, Panel = pcall(require, script.Parent.PanelController)
		if ok and Panel.isOpen() and PartyController.isOpen() then
			refs.panel.Visible = false
		end
		if party then
			refreshMarks() -- (characters come and go)
		end
	end)
end

return PartyController

--[[
The start menu: it's about YOUR world.
  ▶ PLAY              closes the menu: you play right here on the shared ocean (first-timers never see the menu)
  💌 INVITE FRIENDS   the big one: bring friends to see your raft (they arrive in your world; you both get a crate)
  👀 VISIT RAFTS      look at friends' rafts and the biggest ones
  🔄 RESET MY WORLD   start over (asks first)
Showing your raft to friends is pushed everywhere: a pulsing 💌 INVITE button stays on screen, and when there's
something to show (a bigger raft, 10 more floors, back from a trip) a card asks if you'd like to invite someone
(ModeService.Nudge). ModeService does the travelling, the reset and the friend gifts.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local MenuController = { Name = "MenuController", Order = 5 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui, shade, box, status, badge, worldLine, inviteButton, confirmBox, nudgeCard
local buttons = {}

local function modeOf()
	return workspace:GetAttribute("Mode") or "hub"
end

local function friendsWorld()
	return modeOf() == "world" and workspace:GetAttribute("WorldOwner") ~= player.UserId
end

local function setBusy(text)
	status.Text = text or ""
	for _, b in buttons do
		b.Active = text == nil
		b.AutoButtonColor = text == nil
	end
end

-- 💌 Ask friends over: the invite names your world (or the friend's world you're in).
function MenuController.invite()
	local owner = modeOf() == "world" and workspace:GetAttribute("WorldOwner") or player.UserId
	Bus.Tap:Fire("invite")
	pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = "w:" .. tostring(owner)
		options.PromptMessage = "Come see my raft! 🛶"
		SocialService:PromptGameInvite(player, options)
	end)
end

local function updateWorldLine()
	local raft = Store.get("raft")
	if friendsWorld() then
		local name = workspace:GetAttribute("WorldOwnerName")
		worldLine.Text = `🏝️ You're in {name ~= "" and name or "a friend"}'s world!`
	elseif raft and raft.tiles then
		local t = Pieces.TIERS[raft.tier or 1]
		worldLine.Text = `{t and t.icon or "⛵"} Your raft: {raft.tierName or ""} · {raft.size or raft.tiles} pieces`
	else
		worldLine.Text = "🌊 Your own ocean, your own raft"
	end
	buttons.reset.Visible = not friendsWorld()
end

function MenuController.open()
	shade.Visible = true
	confirmBox.Visible = false
	setBusy(nil)
	updateWorldLine()
	Theme.pop(box)
end

function MenuController.close()
	shade.Visible = false
end

function MenuController.play()
	Bus.Tap:Fire("menu_play")
	-- (you play right here, on the shared ocean: no teleport, no second loading screen)
	MenuController.close()
	pcall(Net.send, "Mode", "world")
end

local function updateBadge()
	local mode = modeOf()
	if mode == "world" then
		local name = workspace:GetAttribute("WorldOwnerName")
		badge.Text = friendsWorld() and `🏝️ {name ~= "" and string.upper(name) or "A FRIEND"}'S WORLD`
			or "🏝️ YOUR WORLD"
	else
		badge.Text = "🏝️ BUILD THE BIGGEST RAFT"
	end
end

local function bigButton(name, text, color, y, h, size)
	local b = Theme.button({
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.new(1, -60, 0, h),
		TextSize = size or 22,
		Parent = box,
	})
	return b
end

-- "Bring a friend?" at a moment that's better with one (ModeService picks them, rarely). It never stays: LATER,
-- the ✕, Escape or the gamepad's B close it, and so does the bar running out (NUDGE_SECONDS).
local NUDGE_SECONDS = 12
function MenuController.closeNudge()
	if nudgeCard then
		nudgeCard:Destroy()
		nudgeCard = nil
	end
end

local function nudge(n)
	if type(n) ~= "table" or n.kind ~= "invite" then
		return
	end
	MenuController.closeNudge()
	local card = Theme.card({
		Name = "InviteNudge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(460, 168),
		ZIndex = 10,
		Parent = gui,
	})
	nudgeCard = card
	local head, text = Theme.cardHeader(card, n.text or "Bring a friend along?", 86)
	text.Name = "Text"
	text.Size = UDim2.new(1, -70, 1, -10) -- (clear of the ✕)
	local x = Theme.button({
		Name = "Close",
		Text = "✕",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(40, 36),
		TextSize = 16,
		Parent = head,
	})
	local yes = Theme.button({
		Name = "Invite",
		Text = "💌 INVITE A FRIEND",
		BackgroundColor3 = C.mustard,
		Position = UDim2.new(0, 14, 1, -66),
		Size = UDim2.new(0.62, -20, 0, 46),
		TextSize = 16,
		Parent = card,
	})
	local later = Theme.button({
		Name = "Later",
		Text = "LATER",
		BackgroundColor3 = C.slate,
		Position = UDim2.new(0.62, 6, 1, -66),
		Size = UDim2.new(0.38, -20, 0, 46),
		TextSize = 15,
		Parent = card,
	})
	Theme.keyHint(later, "C", "B")
	-- the time left: a bar along the bottom that runs down
	local bar = new("Frame", {
		Name = "Timer",
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 1, -12),
		Size = UDim2.new(1, -36, 0, 5),
		Parent = card,
	}, { Theme.corner("round") })
	Theme.tween(bar, NUDGE_SECONDS, { Size = UDim2.new(0, 0, 0, 5) }, Enum.EasingStyle.Linear)
	local function close()
		if nudgeCard == card then
			MenuController.closeNudge()
		elseif card.Parent then
			card:Destroy()
		end
	end
	yes.Activated:Connect(function()
		close()
		MenuController.invite()
	end)
	later.Activated:Connect(close)
	x.Activated:Connect(close)
	Theme.pop(card)
	task.delay(NUDGE_SECONDS, close)
end

function MenuController:init()
	gui = Theme.screen("Menu", 30, player:WaitForChild("PlayerGui"))
	badge = Theme.title({
		Name = "Badge",
		Text = "",
		Position = UDim2.fromOffset(12, 152),
		Size = UDim2.fromOffset(380, 22),
		TextSize = 15,
		outline = 2,
		Parent = gui,
	})
	-- the 💌 INVITE button that's always there (still: no pulsing for attention)
	inviteButton = Theme.button({
		Name = "InviteFriends",
		Text = "💌 INVITE FRIENDS",
		BackgroundColor3 = C.mustard,
		Position = UDim2.fromOffset(10, 106),
		Size = UDim2.fromOffset(190, 42),
		TextSize = 15,
		Parent = gui,
	})
	inviteButton.Activated:Connect(MenuController.invite)
	-- (Escape or the gamepad's B closes the "bring a friend?" card)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and nudgeCard
			and (
				input.KeyCode == Enum.KeyCode.C
				or input.KeyCode == Enum.KeyCode.Escape
				or input.KeyCode == Enum.KeyCode.ButtonB
			)
		then
			MenuController.closeNudge()
		end
	end)

	shade = new("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.fromRGB(10, 30, 50),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Visible = false,
		Parent = gui,
	})
	box = Theme.card({
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 470),
		Parent = shade,
	})
	Theme.title({
		Name = "Title",
		Text = "BUILD THE BIGGEST RAFT",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -20, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		TextSize = 30,
		Parent = box,
	})
	worldLine = Theme.text({
		Name = "World",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(1, -30, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17,
		Parent = box,
	})
	buttons.play = bigButton("Play", "▶ PLAY", C.good, 100, 70, 30)
	buttons.invite = bigButton("Invite", "💌 INVITE FRIENDS TO SEE YOUR RAFT", C.mustard, 182, 62, 19)
	Theme.text({
		Name = "InviteHint",
		Text = "They sail into your world. You both get a 🎁 supply crate!",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 246),
		Size = UDim2.new(1, -40, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = C.muted,
		Parent = box,
	})
	buttons.visit = bigButton("Visit", "👀 VISIT RAFTS", C.sky, 276, 52, 19)
	buttons.reset = bigButton("Reset", "🔄 RESET MY WORLD", C.slate, 340, 40, 15)
	buttons.play.Activated:Connect(function()
		if buttons.play.Active then
			MenuController.play()
		end
	end)
	buttons.invite.Activated:Connect(MenuController.invite)
	buttons.visit.Activated:Connect(function()
		MenuController.close()
		Bus.Open:Fire("visit")
	end)
	-- reset asks first
	confirmBox = Theme.card({
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -30, 0, 230),
		BackgroundColor3 = Color3.fromRGB(255, 236, 225),
		Visible = false,
		ZIndex = 5,
		Parent = box,
	})
	Theme.cardHeader(confirmBox, "START YOUR WORLD OVER?", 50, C.red, 22)
	Theme.text({
		Name = "Ask",
		Text = "Your raft goes back to a tiny platform and your bag empties. Your level, journal and blueprints stay.",
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 96),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17,
		ZIndex = 6,
		Parent = confirmBox,
	})
	local yes = Theme.button({
		Name = "Yes",
		Text = "YES, START OVER",
		BackgroundColor3 = C.red,
		Position = UDim2.new(0, 12, 1, -62),
		Size = UDim2.new(0.5, -18, 0, 48),
		TextSize = 15,
		ZIndex = 6,
		Parent = confirmBox,
	})
	local no = Theme.button({
		Name = "No",
		Text = "NO, KEEP IT",
		BackgroundColor3 = C.good,
		Position = UDim2.new(0.5, 6, 1, -62),
		Size = UDim2.new(0.5, -18, 0, 48),
		TextSize = 15,
		ZIndex = 6,
		Parent = confirmBox,
	})
	buttons.reset.Activated:Connect(function()
		confirmBox.Visible = true
	end)
	no.Activated:Connect(function()
		confirmBox.Visible = false
	end)
	yes.Activated:Connect(function()
		confirmBox.Visible = false
		Net.send("ResetWorld")
		Bus.Tap:Fire("reset_world")
		MenuController.close()
	end)
	status = Theme.text({
		Name = "Status",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -20, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = C.muted,
		Parent = box,
	})
	status.Text = ""
	Net.listen("Menu", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.travelling then
			setBusy(m.travelling == "friend" and "💌 Sailing to your friend's world..." or status.Text)
			shade.Visible = true
		elseif m.close then
			if m.note then
				setBusy(m.note)
				task.delay(2.5, MenuController.close)
			else
				MenuController.close()
			end
		end
	end)
	Net.listen("Nudge", nudge)
	Bus.Menu:Connect(function(kind)
		if kind == "invite" then
			MenuController.invite()
		else
			MenuController.open()
		end
	end)
	workspace:GetAttributeChangedSignal("Mode"):Connect(updateBadge)
	Store.Changed:Connect(function(partial)
		if partial.raft and shade.Visible then
			updateWorldLine()
		end
	end)
	updateBadge()
	-- no menu on arrival: everyone lands straight in the game (every screen before playing loses players); the
	-- menu is one tap away (its button, top left)
	updateBadge()
end

-- (tests)
MenuController.buttons = buttons
function MenuController.isOpen()
	return shade.Visible
end
function MenuController.status()
	return status.Text
end
function MenuController.nudgeCard()
	return nudgeCard
end

return MenuController

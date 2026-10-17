--[[
The winners' cards (FeedbackService decides who and when):

  "enjoy"  ARE YOU LIKING THE GAME?   YES 👍 / NO 👎   (NO: then WHAT WAS WRONG? tick one or more of
           Constants.FEEDBACK_REASONS; SEND only works once one is ticked)
  "like"   Give the game a 👍 Like on its page: it really helps.   ⭐ FAVOURITE / LATER
           (Roblox doesn't let a game press its like button; FAVOURITE opens Roblox's own favourite prompt)

Answering the first (either way) gives the Thank-You Trail; its card comes up in the HUD's popup stack.

Everything inside has its own band (title 16-46, words 50-80, buttons 88-134 of 146) and the words shrink to fit.
The buttons are Modal, so the mouse comes free of first person while the card is up. Y / N answer from the
keyboard. The card closes itself when the next game starts.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(script.Parent.Parent.UI.Layout)

local FeedbackController = { Name = "FeedbackController", Order = 50 }

local C = Theme.Color
local player = Players.LocalPlayer
local gui
local card
local current -- "enjoy" | "like"

local function close()
	if card then
		card:Destroy()
		card = nil
	end
	current = nil
end

local picked -- the reasons ticked on the NO card: { [key] = true }
local showReasons -- (set below)

function FeedbackController.answer(value)
	if not current then
		return false
	end
	local kind = current
	if kind == "enjoy" and value == false then
		-- (a NO says why first: the reasons card, which won't send without one)
		showReasons()
		return true
	end
	if kind == "like" and value == "ok" then
		pcall(function()
			game:GetService("AvatarEditorService"):PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end
	Net.send("Feedback", kind, value)
	close()
	return true
end

local function button(parent, name, text, x, dark, value)
	local b = Theme.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, x, 0, 88),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = dark and C.ink or C.white,
		Text = text,
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = dark and C.white or C.ink,
		AutoButtonColor = true,
		Modal = true,
		Parent = parent,
	}, { Theme.corner(4), Theme.stroke(2, C.ink) })
	b.Activated:Connect(function()
		FeedbackController.answer(value)
	end)
	return b
end

function FeedbackController.show(kind)
	close()
	current = kind
	card = Theme.card({
		Name = "Ask",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(420, 146),
		BackgroundColor3 = C.white,
		Parent = gui,
	})
	Layout.modal("ask", card)
	card.Visible = not Layout.panel() -- (waits behind the shop panel while that's open)
	if kind == "enjoy" then
		Theme.title({
			Text = "ARE YOU LIKING THE GAME?",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.ink,
			outline = false,
			Parent = card,
		})
		Theme.text({
			Text = "Tell us straight: YES or NO, you get the Thank-You Trail.",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 50),
			fit = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.muted,
			Parent = card,
		})
		button(card, "Yes", "YES 👍", -82, true, true)
		button(card, "No", "NO 👎", 82, false, false)
	else
		Theme.title({
			Text = "GIVE THE GAME A 👍 LIKE",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.ink,
			outline = false,
			Parent = card,
		})
		Theme.text({
			Text = "Glad you're having fun! A like on the game's page really helps.",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 50),
			fit = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.muted,
			Parent = card,
		})
		button(card, "Ok", "⭐ FAVOURITE", -82, true, "ok")
		button(card, "Later", "LATER", 82, false, "later")
	end
	Theme.pop(card)
	return card
end

-- The NO card's second step: tick one or more reasons, then SEND (greyed out until one is ticked).
showReasons = function()
	if not card then
		return
	end
	current = "why"
	picked = {}
	local reasons = Constants.FEEDBACK_REASONS
	local rows = math.ceil(#reasons / 2)
	for _, ch in card:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	card.Size = UDim2.fromOffset(460, 104 + rows * 44 + 58)
	Theme.title({
		Text = "WHAT WAS WRONG?",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		outline = false,
		Parent = card,
	})
	Theme.text({
		Text = "Pick one or more. We read every answer and fix what you tell us.",
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 48),
		fit = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
		Parent = card,
	})
	local send
	local function paintSend()
		local any = next(picked) ~= nil
		send.Active = any
		send.AutoButtonColor = any
		send.BackgroundColor3 = any and C.ink or Color3.fromRGB(205, 205, 210)
		send.Text = any and "SEND" or "PICK AT LEAST ONE"
	end
	for i, r in reasons do
		local col, row = (i - 1) % 2, (i - 1) // 2
		local b = Theme.new("TextButton", {
			Name = "Reason_" .. r.key,
			Position = UDim2.fromOffset(12 + col * 222, 82 + row * 44),
			Size = UDim2.fromOffset(214, 38),
			BackgroundColor3 = C.white,
			Text = `{r.icon}  {r.text}`,
			Font = Theme.Body,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = C.ink,
			AutoButtonColor = true,
			Modal = true,
			Parent = card,
		}, { Theme.corner(4), Theme.stroke(2, C.ink) })
		b.Activated:Connect(function()
			FeedbackController.toggle(r.key)
		end)
	end
	send = Theme.new("TextButton", {
		Name = "Send",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82 + rows * 44 + 8),
		Size = UDim2.fromOffset(220, 42),
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.white,
		Modal = true,
		Parent = card,
	}, { Theme.corner(4) })
	send.Activated:Connect(function()
		FeedbackController.send()
	end)
	FeedbackController._paint = function()
		for _, r in reasons do
			local b = card and card:FindFirstChild("Reason_" .. r.key)
			if b then
				local on = picked[r.key] == true
				b.BackgroundColor3 = on and C.ink or C.white
				b.TextColor3 = on and C.white or C.ink
			end
		end
		paintSend()
	end
	paintSend()
end

-- Tick or untick a reason on the NO card.
function FeedbackController.toggle(key)
	if current ~= "why" or not picked then
		return false
	end
	picked[key] = not picked[key] or nil
	if FeedbackController._paint then
		FeedbackController._paint()
	end
	return true
end

-- Send the NO with its reasons (nothing happens until at least one is ticked).
function FeedbackController.send()
	if current ~= "why" or not picked or next(picked) == nil then
		return false
	end
	local list = {}
	for _, r in Constants.FEEDBACK_REASONS do
		if picked[r.key] then
			table.insert(list, r.key)
		end
	end
	Net.send("Feedback", "enjoy", false, list)
	close()
	return true
end

function FeedbackController.current()
	return current, card
end

function FeedbackController:init()
	gui = Theme.screen("Ask", 20, player:WaitForChild("PlayerGui"))
	Net.listen("Ask", function(a)
		if type(a) == "table" and (a.kind == "enjoy" or a.kind == "like") then
			FeedbackController.show(a.kind)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current or current == "why" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Y then
			FeedbackController.answer(current == "enjoy" and true or "ok")
		elseif input.KeyCode == Enum.KeyCode.N then
			FeedbackController.answer(current == "enjoy" and false or "later")
		end
	end)
	Layout.onPanel(function(open)
		if card then
			card.Visible = not open
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.match and partial.match.phase ~= "victory" and current and current ~= "why" then
			close() -- (the next game started: no answer; a NO already given waits for its reasons)
		end
	end)
end

return FeedbackController

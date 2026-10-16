--[[
The winners' cards (FeedbackService decides who and when):

  "enjoy"  ARE YOU LIKING THE GAME?   YES 👍 / NO 👎
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

function FeedbackController.answer(value)
	if not current then
		return false
	end
	local kind = current
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
		if processed or not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.Y then
			FeedbackController.answer(current == "enjoy" and true or "ok")
		elseif input.KeyCode == Enum.KeyCode.N then
			FeedbackController.answer(current == "enjoy" and false or "later")
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.match and partial.match.phase ~= "victory" and current then
			close() -- (the next game started: no answer)
		end
	end)
end

return FeedbackController

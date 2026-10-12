-- Shows each player only the prompts that make sense for them: Steal on other players' dragons, Sell, Level Up
-- and +10 Levels on your own, Buy on the road when your hands are free, and so on. (The server checks everything again.)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Store = require(script.Parent.Parent.Store)

local player = Players.LocalPlayer

local PromptController = { Name = "PromptController", Order = 40 }

local function isTeam(userId)
	for _, id in Store.state.team or {} do
		if id == userId then
			return true
		end
	end
	return false
end

function PromptController.shouldShow(prompt)
	local s = Store.state
	local kind = prompt:GetAttribute("Kind")
	local owner = prompt:GetAttribute("OwnerUserId")
	local mine = owner == player.UserId
	local carrying = s.carrying ~= nil and s.carrying ~= false
	if kind == "steal" then
		return not mine and not carrying and not isTeam(owner)
	elseif kind == "sell" or kind == "grow" or kind == "levelup" then
		return mine and not carrying
	elseif kind == "nest" or kind == "hatch" then
		return mine
	elseif kind == "buy" or kind == "buynow" or kind == "grab" then
		return not carrying
	elseif kind == "free" or kind == "practice" then
		return s.tutorialDone == false
	end
	return true
end

local function apply(prompt)
	local show = PromptController.shouldShow(prompt)
	if prompt.Enabled ~= show then
		prompt.Enabled = show
	end
end

function PromptController:init()
	CollectionService:GetInstanceAddedSignal("DragonPrompt"):Connect(apply)
	Store.Changed:Connect(function(partial)
		if partial.carrying ~= nil or partial.team ~= nil or partial.tutorialDone ~= nil then
			for _, prompt in CollectionService:GetTagged("DragonPrompt") do
				apply(prompt)
			end
		end
	end)
	for _, prompt in CollectionService:GetTagged("DragonPrompt") do
		apply(prompt)
	end
end

return PromptController

-- The proximity prompts, from your side (the server checks everything again):
--   * your cabin's BUILD and door-sign prompts show only to you (OwnerUserId); in anyone else's cabin you're a guest
--   * BUILD and the door sign open the BUILD panel, the engine room board opens TRAIN, a Hall plaque opens HALL
--     at that record
--   * piles take TOOLRACK_HOLD to collect once your Tool Rack is built (COLLECT_HOLD before)
--   * a pile you already took at this stop hides its prompt (NodeController hides the pile itself)
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Store = require(script.Parent.Parent.Store)

local player = Players.LocalPlayer

local PromptController = { Name = "PromptController", Order = 40 }

local taken = {} -- [nodeId] = true: piles this player took at this stop

local function panels()
	return require(script.Parent.PanelController)
end

function PromptController.shouldShow(prompt)
	local name = prompt.Name
	if name == "Prompt_build" or name == "Prompt_paint" then
		local owner = prompt:GetAttribute("OwnerUserId")
		return owner == player.UserId
	elseif name == "Prompt_node" then
		local id = prompt:GetAttribute("NodeId")
		return not (id and taken[id])
	end
	return nil -- (leave it as the server set it)
end

local function apply(prompt)
	local show = PromptController.shouldShow(prompt)
	if show ~= nil and prompt.Enabled ~= show then
		prompt.Enabled = show
	end
	if prompt.Name == "Prompt_node" and prompt.ObjectText ~= "Blueprint" then
		local built = Store.state.cabin and Store.state.cabin.built
		local hold = Formulas.collectHold(built)
		if prompt.HoldDuration ~= hold then
			prompt.HoldDuration = hold
		end
	end
end
PromptController.apply = apply

local watched = setmetatable({}, { __mode = "k" })
local function watch(prompt)
	if not prompt:IsA("ProximityPrompt") or watched[prompt] then
		return
	end
	watched[prompt] = true
	apply(prompt)
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		apply(prompt)
	end)
	-- the server turns a cabin's prompts on when someone moves in: hide them again if they aren't ours
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		apply(prompt)
	end)
end

local function applyAll()
	for prompt in watched do
		if prompt.Parent then
			apply(prompt)
		end
	end
end

function PromptController.markTaken(ids, reset)
	if reset then
		taken = {}
	end
	for _, id in ids or {} do
		taken[id] = true
	end
	applyAll()
end

function PromptController.isTaken(id)
	return taken[id] == true
end

function PromptController:init()
	for _, d in workspace:GetDescendants() do
		watch(d)
	end
	pcall(function()
		workspace.DescendantAdded:Connect(watch)
	end)
	-- (the mock engine has no DescendantAdded: look again now and then)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, d in workspace:GetDescendants() do
				if d:IsA("ProximityPrompt") and not watched[d] then
					watch(d)
				end
			end
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.cabin then
			applyAll()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		PromptController.opened(prompt)
	end)
end

-- What a prompt opens on this side.
function PromptController.opened(prompt)
	local name = prompt.Name
	if name == "Prompt_build" or name == "Prompt_paint" then
		panels().open("build")
	elseif name == "Prompt_train" then
		panels().open("train")
	elseif name == "Prompt_record" then
		panels().open("hall", { rank = prompt:GetAttribute("Rank") })
	end
end

return PromptController

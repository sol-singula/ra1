--[[
The Block Party meter (from the top of the hour to the bloom): the sunflower's stage, waters / goal, time left, your
waters (state.minWaters needed for the reward: 1 in a private server, else Config.BlockParty.reward.minWaters), and a Water button. The sunflower's Water prompt
waters too.

  BlockPartyController.state()   the last BlockPartyState
  BlockPartyController.gui
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local BlockPartyController = {}

local state
local meter, stageLabel, fill, countLabel, timeLabel, yoursLabel

local STAGE_TEXT = {
	drooping = "🌻 The sunflower is drooping",
	perking = "🌻 It's perking up!",
	standing = "🌻 Standing tall!",
	bloom = "🌻 BLOOM!",
}

function BlockPartyController.state()
	return state
end

local function water()
	Net.request("BlockParty", "water", {})
end

local function refresh()
	if not meter then
		return
	end
	local open = state ~= nil and state.phase == "open"
	meter.Visible = open
	if not open then
		return
	end
	stageLabel.Text = STAGE_TEXT[state.stage] or ""
	fill.Size = UDim2.new(math.clamp(state.waters / math.max(1, state.goal), 0, 1), 0, 1, 0)
	countLabel.Text = `{state.waters} / {state.goal} waters`
	timeLabel.Text = UI.duration((state.endsAt or 0) - Clock.now()) .. " left"
	local need = state.minWaters or Config.BlockParty.reward.minWaters
	yoursLabel.Text = if state.yourWaters >= need
		then `Your waters: {state.yourWaters} ✓ reward ready`
		else `Your waters: {state.yourWaters} ({need} needed)`
end

function BlockPartyController.set(newState)
	state = newState
	refresh()
end

function BlockPartyController:Start()
	local gui = UI.screen("BlockParty")
	BlockPartyController.gui = gui
	meter = UI.frame(gui, {
		Name = "Meter",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(300, 220),
		Visible = false,
	})
	UI.list(meter, 6)
	stageLabel = UI.label(meter, "", { Name = "Stage", Size = UDim2.new(1, -16, 0, 30) })
	-- GA-02: a flat sunflower-petal fill (no gradient, no shine) on a dark track
	local bar = UI.frame(meter, {
		Name = "Bar",
		Size = UDim2.new(1, -16, 0, 22),
		BackgroundColor3 = UI.COLORS.meterTrack,
		BackgroundTransparency = 0.35,
	})
	fill = UI.frame(bar, { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UI.COLORS.meter })
	countLabel = UI.label(meter, "", { Name = "Count", Size = UDim2.new(1, -16, 0, 24) })
	timeLabel = UI.label(meter, "", { Name = "TimeLeft", Size = UDim2.new(1, -16, 0, 24) })
	yoursLabel = UI.label(meter, "", { Name = "Yours", Size = UDim2.new(1, -16, 0, 24) })
	UI.button(meter, "💧 Water", water, { Name = "Water", Size = UDim2.new(1, -16, 0, 48) })

	Net.on("BlockPartyState", BlockPartyController.set)
	ClientState.Changed:Connect(function(roots)
		if roots == nil and ClientState.extra and ClientState.extra.blockParty then
			BlockPartyController.set(ClientState.extra.blockParty)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if
			prompt.Name == "Water"
			and prompt.Parent
			and prompt.Parent.Parent
			and prompt.Parent.Parent.Name == "Sunflower"
		then
			water()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			refresh()
		end
	end)
end

return BlockPartyController

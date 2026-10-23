--[[
Quests: the 5 starter quests in order (each pays itself when done), then, once all 5 are done, the 3 daily quests as
progress bars with Claim (300 x plotLevel^2) and the time to the 00:00 UTC reset in local time.

  QuestController.open() / close() / isOpen() / fill()
  QuestController.TEXT    [questId] = what it asks
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local QuestController = {}

QuestController.TEXT = {
	harvest5 = "Harvest 5 crops",
	plot2 = "Upgrade your plot to level 2",
	keepMut = "Keep a mutated crop",
	pedestal = "Show an item on a pedestal",
	help1 = "Water a neighbour's crop",
	harvest30 = "Harvest 30 crops",
	help3 = "Water 3 neighbours' crops",
	sunflower5 = "Water the sunflower 5 times",
}

local DAY = 86400

local controllers
local modal, countdown

local function starterDone(p)
	for _, q in Config.Quests.starter do
		local st = p.quests.starter[q.key]
		if not (st and st.claimed) then
			return false
		end
	end
	return true
end

local function resetText(now)
	local nextAt = (Clock.utcDay(now) + 1) * DAY
	return `New quests at {controllers.HudController.localTime(nextAt)} (in {UI.duration(nextAt - now)})`
end

local function rewardText(q)
	if q.reward.coins then
		return `🪙 {q.reward.coins}`
	end
	local parts = {}
	for seed, n in q.reward.seeds do
		table.insert(parts, `{n} {Config.Seeds[seed].name}`)
	end
	return table.concat(parts, ", ")
end

function QuestController.fill()
	modal.clear()
	countdown = nil
	local p = ClientState.profile
	if not p then
		return
	end
	if not starterDone(p) then
		for i, q in Config.Quests.starter do
			local st = p.quests.starter[q.key] or { n = 0, claimed = false }
			local text = `{i}. {QuestController.TEXT[q.key]} ({math.min(st.n, q.n)}/{q.n}) · {rewardText(q)}`
			UI.label(modal.body, (if st.claimed then "✓ " else "") .. text, {
				Name = "Starter_" .. q.key,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 34),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if st.claimed then UI.COLORS.green else UI.COLORS.ink,
			})
		end
		return
	end
	local dq = p.quests.daily
	local fresh = dq.day ~= Clock.utcDay(Clock.now()) -- the server resets it on the next progress
	local coins = Config.Quests.dailyCoinsPerLevelSq * p.plotLevel ^ 2
	for i, q in Config.Quests.daily do
		local n = if fresh then 0 else math.min(dq.progress[q.key] or 0, q.n)
		local claimed = not fresh and dq.claimed[q.key] == true
		local row = UI.frame(modal.body, { Name = "Daily_" .. q.key, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 90) })
		UI.label(row, `{QuestController.TEXT[q.key]} · 🪙 {UI.money(coins)}`, {
			Name = "Text",
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local track = UI.frame(row, {
			Name = "Track",
			Position = UDim2.fromOffset(8, 38),
			Size = UDim2.new(1, -128, 0, 20),
			BackgroundColor3 = UI.COLORS.grey,
		})
		UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(n / q.n, 1), BackgroundColor3 = UI.COLORS.green })
		UI.label(
			row,
			`{n}/{q.n}`,
			{ Name = "Count", Position = UDim2.fromOffset(8, 62), Size = UDim2.new(0.5, 0, 0, 22) }
		)
		if claimed then
			UI.label(row, "✓ Claimed", {
				Name = "Done",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 34),
				Size = UDim2.fromOffset(110, 40),
				TextColor3 = UI.COLORS.green,
			})
		elseif n >= q.n then
			UI.button(row, "Claim", function()
				Net.request("Quest", "claim", { questId = q.key })
			end, {
				Name = "Claim",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 34),
				Size = UDim2.fromOffset(110, 48),
			})
		end
	end
	countdown = UI.label(
		modal.body,
		resetText(Clock.now()),
		{ Name = "Reset", LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 26) }
	)
end

function QuestController.open()
	QuestController.fill()
	modal.open()
end

function QuestController.close()
	modal.close()
end

function QuestController.isOpen()
	return modal.isOpen()
end

function QuestController:Init(all)
	controllers = all
end

function QuestController:Start()
	modal = UI.modal("Quests", "Quests")
	modal.card.Size = UDim2.fromOffset(500, 420)
	ClientState.Changed:Connect(function(roots)
		if modal.isOpen() and (roots == nil or roots.quests or roots.plotLevel) then
			QuestController.fill()
		end
	end)
	task.spawn(function()
		while true do
			if modal.isOpen() and countdown then
				countdown.Text = resetText(Clock.now())
			end
			task.wait(1)
		end
	end)
end

return QuestController

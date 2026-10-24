--[[
The daily calendar: 7 day tiles (today's highlighted), the streak, Claim (once per UTC day) and when it resets, in
local time. It opens by itself at the first session's calendar beat (firstSession.calendarShown turning true, once the
shop is closed and no Patch line is up; the notification opt-in is asked then, in a pcall), and on later logins when
today's day is still unclaimed.

  DailyController.open() / close() / isOpen() / fill()
  DailyController.claimable(now?) -> boolean
  DailyController.rewardText(entry, cycle)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local DailyController = {}

local DAY = 86400

local controllers
local modal, reset
local wasShown -- firstSession.calendarShown as last seen (nil until the first load)
local wantOpen = false

local function today(now)
	return Clock.utcDay(now - Config.Daily.resetUtcHour * 3600)
end

function DailyController.claimable(now)
	local d = ClientState.get("daily")
	return d ~= nil and today(now or Clock.now()) > d.lastClaimDay
end

function DailyController.rewardText(entry, cycle)
	local parts = {}
	if entry.coins then
		table.insert(parts, `🪙 {UI.money(entry.coins)}`)
	end
	for seed, n in entry.seeds or {} do
		table.insert(parts, `{n} {Config.Seeds[seed].name}`)
	end
	if entry.firstCycle and cycle == 1 then
		table.insert(parts, "Petal Trail")
	elseif entry.repeatCoins and cycle > 1 then
		table.insert(parts, `🪙 {UI.money(entry.repeatCoins)}`)
	end
	return table.concat(parts, " + ")
end

local function resetText(now)
	local nextAt = (today(now) + 1) * DAY + Config.Daily.resetUtcHour * 3600
	return `New day at {controllers.HudController.localTime(nextAt)} (in {UI.duration(nextAt - now)})`
end

function DailyController.fill()
	modal.clear()
	local d = ClientState.get("daily")
	if not d then
		return
	end
	local now = Clock.now()
	local claimable = DailyController.claimable(now)
	local row = Instance.new("Frame")
	row.Name = "Days"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 120)
	row.Parent = modal.body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 7, -6, 1, 0)
	layout.CellPadding = UDim2.fromOffset(6, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i, entry in Config.Daily.days do
		local done = i < d.day
		local current = i == d.day
		local tile = UI.frame(row, {
			Name = "Day_" .. i,
			LayoutOrder = i,
			BackgroundColor3 = if current then UI.COLORS.highlight elseif done then UI.COLORS.grey else UI.COLORS.card,
		})
		UI.label(
			tile,
			(if done then "✓ " else "") .. "Day " .. i,
			{ Name = "Title", Size = UDim2.new(1, -4, 0.3, 0) }
		)
		UI.label(tile, DailyController.rewardText(entry, d.cycle), {
			Name = "Reward",
			Position = UDim2.fromScale(0, 0.35),
			Size = UDim2.new(1, -4, 0.6, 0),
			TextWrapped = true,
		})
	end
	UI.label(modal.body, `🔥 Streak: {d.streak}`, { Name = "Streak" })
	UI.button(modal.body, if claimable then `Claim Day {d.day}` else "Come back tomorrow!", function()
		if DailyController.claimable() then
			Net.request("Daily", "claim", {})
		end
	end, {
		Name = "Claim",
		Active = claimable,
		AutoButtonColor = claimable,
		BackgroundColor3 = if claimable then UI.COLORS.green else UI.COLORS.grey,
	})
	reset = UI.label(modal.body, resetText(now), { Name = "Reset", Size = UDim2.new(1, 0, 0, 26) })
end

function DailyController.open()
	DailyController.fill()
	modal.open()
end

function DailyController.close()
	modal.close()
end

function DailyController.isOpen()
	return modal.isOpen()
end

local function optIn()
	pcall(function()
		local service = game:GetService("ExperienceNotificationService")
		if service:CanPromptOptInAsync() then
			service:PromptOptIn()
		end
	end)
end

-- the shop is closed and no Patch line is up
local function clear()
	local shop, patch = controllers.ShopController, controllers.PatchController
	return not (shop and shop.isOpen and shop.isOpen()) and not (patch and patch.showing and patch.showing())
end

local function onChanged(roots)
	local p = ClientState.profile
	if not p then
		return
	end
	local shown = p.firstSession.calendarShown == true
	if wasShown == nil then
		-- the first load: a later login opens it when today's day is unclaimed
		wantOpen = shown and DailyController.claimable()
	elseif shown and not wasShown then
		wantOpen = true -- the first session's calendar beat
		optIn()
	end
	wasShown = shown
	if modal.isOpen() and (roots == nil or roots.daily) then
		DailyController.fill()
	end
end

function DailyController:Init(all)
	controllers = all
end

function DailyController:Start()
	modal = UI.modal("Daily", "Daily Calendar")
	modal.card.Size = UDim2.fromOffset(640, 380)
	ClientState.Changed:Connect(onChanged)
	if ClientState.profile then
		onChanged(nil)
	end
	task.spawn(function()
		while true do
			if wantOpen and clear() then
				wantOpen = false
				DailyController.open()
			end
			if modal.isOpen() and reset then
				reset.Text = resetText(Clock.now())
			end
			task.wait(0.5)
		end
	end)
end

return DailyController

--[[
The DAILY panel (Net "Daily", DailyService): the 7-day calendar across the top (seven tiles, the claimed ones
ticked, today's glowing with a CLAIM button), the streak, and the weekly Big Contract under it (four parts with
bars, the reward, the days left). It opens by itself once a session when the day's reward is waiting.

  DailyController.refs   the panel's pieces (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Layout = require(script.Parent.Parent.UI.Layout)
local Panel = require(script.Parent.Parent.UI.Panel)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local DailyController = { Name = "DailyController", Order = 48 }

local C = Theme.Color
local refs = { tiles = {}, parts = {} }
DailyController.refs = refs
local ORANGE = Color3.fromRGB(240, 120, 60)
local autoOpened = false

local function rewardText(r)
	local out = {}
	if (r.cash or 0) > 0 then
		table.insert(out, "💵 " .. Format.num(r.cash))
	end
	if (r.gems or 0) > 0 then
		table.insert(out, `💎 {r.gems}`)
	end
	if (r.seeds or 0) > 0 then
		table.insert(out, `🌟 {r.seeds} seeds`)
	end
	return table.concat(out, "\n")
end

local function paint(d)
	if type(d) ~= "table" or not d.today then
		return
	end
	local today = d.today
	for i, tile in refs.tiles do
		local claimed = i < today.day or (i == today.day and not today.ready)
		local now = i == today.day
		tile.card.BackgroundColor3 = now and (today.ready and Color3.fromRGB(255, 220, 120) or C.good)
			or (claimed and Color3.fromRGB(200, 230, 200) or C.paper)
		tile.reward.Text = rewardText(d.days and d.days[i] or {})
		tile.tick.Visible = claimed
	end
	refs.claim.Visible = today.ready == true
	refs.claim.Text = `CLAIM DAY {today.day}`
	refs.streak.Text = today.ready
			and (today.held and `🔥 Streak {today.streak}: claim today to keep it!` or "Missed a day: back one day, not to zero")
		or `🔥 Streak {today.streak} · come back tomorrow for day {today.day % 7 + 1}`
	refs.seeds.Text = `🌟 Golden seeds: {d.seeds or 0} (each makes a planting golden)`
	local w = d.weekly or {}
	for i, row in refs.parts do
		local part = w.parts and w.parts[i]
		row.frame.Visible = part ~= nil
		if part then
			row.text.Text = (part.done and "✅ " or "") .. part.text
			row.count.Text = `{Format.num(part.have or 0)} / {Format.num(part.n)}`
			row.fill.Size = UDim2.fromScale(math.clamp((part.have or 0) / math.max(1, part.n), 0.02, 1), 1)
			row.fill.BackgroundColor3 = part.done and C.good or ORANGE
		end
	end
	local r = w.reward or {}
	refs.weeklyPay.Text = w.paid and "PAID! A new one on Monday"
		or `All four: 💵 {Format.num(r.cash or 0)} + 💎 {r.gems or 0} · {Format.time(math.max(0, w.ends or 0))} left`
end

function DailyController:init()
	local panel = Panel.new("calendar", "DAILY REWARDS", ORANGE, Vector2.new(660, 430))
	refs.panel = panel
	local body = panel.body
	local W = 86
	for i = 1, 7 do
		local card = Theme.card({
			Name = "Day" .. i,
			Position = UDim2.fromOffset((i - 1) * (W + 6), 0),
			Size = UDim2.fromOffset(W, 116),
			Parent = body,
		})
		Theme.text({
			Name = "Day",
			Text = i == 7 and "DAY 7 ★" or `DAY {i}`,
			Font = Theme.Display,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			fit = 16,
			Parent = card,
		})
		local reward = Theme.text({
			Name = "Reward",
			Text = "",
			Position = UDim2.fromOffset(4, 28),
			Size = UDim2.new(1, -8, 1, -32),
			TextXAlignment = Enum.TextXAlignment.Center,
			fit = 14,
			Parent = card,
		})
		local tick = Theme.text({
			Name = "Tick",
			Text = "✅",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -8),
			Size = UDim2.fromOffset(24, 24),
			Visible = false,
			Parent = card,
		})
		refs.tiles[i] = { card = card, reward = reward, tick = tick }
	end
	refs.claim = Theme.button({
		Name = "Claim",
		Text = "CLAIM",
		BackgroundColor3 = C.good,
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.fromOffset(200, 44),
		Visible = false,
		Parent = body,
	})
	refs.claim.Activated:Connect(function()
		Bus.Tap:Fire("calendar_claim")
		Net.send("Daily", "claim")
	end)
	refs.streak = Theme.text({
		Name = "Streak",
		Text = "",
		Position = UDim2.fromOffset(210, 124),
		Size = UDim2.new(1, -210, 0, 24),
		fit = 17,
		Parent = body,
	})
	refs.seeds = Theme.text({
		Name = "Seeds",
		Text = "",
		Position = UDim2.fromOffset(210, 148),
		Size = UDim2.new(1, -210, 0, 20),
		TextColor3 = C.ink,
		fit = 14,
		Parent = body,
	})
	Theme.text({
		Name = "WeeklyTitle",
		Text = "WEEKLY BIG CONTRACT",
		Font = Theme.Display,
		Position = UDim2.fromOffset(0, 180),
		Size = UDim2.new(1, 0, 0, 26),
		fit = 20,
		Parent = body,
	})
	for i = 1, 4 do
		local frame = Theme.new("Frame", {
			Name = "Part" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 210 + (i - 1) * 30),
			Size = UDim2.new(1, 0, 0, 26),
			Parent = body,
		})
		local text = Theme.text({
			Name = "Text",
			Text = "",
			Size = UDim2.new(0.5, 0, 1, 0),
			fit = 16,
			Parent = frame,
		})
		local _, fill = Theme.bar({
			Name = "Bar",
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.new(0.34, 0, 0, 16),
			Parent = frame,
		}, ORANGE)
		local count = Theme.text({
			Name = "Count",
			Text = "",
			Position = UDim2.new(0.86, 0, 0, 0),
			Size = UDim2.new(0.14, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			fit = 15,
			Parent = frame,
		})
		refs.parts[i] = { frame = frame, text = text, fill = fill, count = count }
	end
	refs.weeklyPay = Theme.text({
		Name = "WeeklyPay",
		Text = "",
		Font = Theme.Display,
		Position = UDim2.fromOffset(0, 334),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Color3.fromRGB(30, 110, 50),
		fit = 17,
		Parent = body,
	})
	panel.onOpen = function()
		Net.send("Daily", "open")
	end
	Store.Changed:Connect(function(partial)
		if partial.daily ~= nil then
			paint(partial.daily)
			-- (the day's reward waiting: open by itself, once a session, after the away card)
			local d = partial.daily
			if not autoOpened and type(d) == "table" and d.today and d.today.ready then
				autoOpened = true
				task.spawn(function()
					task.wait(1.5)
					for _ = 1, 120 do
						if not Layout.modalOpen() then
							break
						end
						task.wait(0.5)
					end
					if Panel.current() == nil then
						Bus.Panel:Fire("calendar")
					end
				end)
			end
		end
	end)
end

return DailyController

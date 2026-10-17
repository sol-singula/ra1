--[[
The banners (server/Notify.lua, Net "Announce"): a strip slides down under the top bar with an icon and a few words,
holds, and slides away; the next one waits its turn (at most a handful wait, the oldest dropped). The kind picks the
look: "start" and "win" are big and black, "lose" muted, "status" gold, "admin" red, "party" blue, "info" white.
Hidden while the panel is open (the queue waits).

Someone joining ("join") isn't a banner: a small chip slides in at the left, up to three at once, gone after a few
seconds. Your side's colour and "joined your team!" for a new teammate; white with the enemy's colour and "new
enemy!" for the other side.

  NotifyController.show({ text, kind, color?, icon?, seconds? })   (tests call it too)
  NotifyController.current()   the banner on screen, or nil
  NotifyController.queued()    how many are waiting
  NotifyController.chips()     the join chips on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)

local NotifyController = { Name = "NotifyController", Order = 42 }

local C = Theme.Color
local LOOK = {
	start = { bg = C.ink, fg = C.white, icon = "⚔️", big = true },
	win = { bg = C.ink, fg = C.white, icon = "🏆", big = true },
	lose = { bg = Color3.fromRGB(90, 90, 98), fg = C.white, icon = "💀" },
	status = { bg = Color3.fromRGB(255, 205, 50), fg = C.ink, icon = "⭐" },
	admin = { bg = C.red, fg = C.white, icon = "🛡️" },
	party = { bg = C.blue, fg = C.white, icon = "👥" },
	info = { bg = C.white, fg = C.ink, icon = "📣" },
}
local MAX_QUEUE = 5

local gui, strip, label, iconLabel
local queue = {}
local showing -- the message on screen
local untilT = 0

function NotifyController.current()
	return showing
end

function NotifyController.queued()
	return #queue
end

local function present(msg)
	local look = LOOK[msg.kind] or LOOK.info
	showing = msg
	strip.BackgroundColor3 = msg.color or look.bg
	label.TextColor3 = look.fg
	label.Text = string.upper(msg.text)
	iconLabel.Text = msg.icon or look.icon
	strip.Size = UDim2.fromOffset(look.big and 520 or 440, look.big and 56 or 44)
	strip.Visible = true
	strip.Position = UDim2.new(0.5, 0, 0, 40)
	Theme.tween(strip, 0.3, { Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Back)
	Theme.pop(strip)
	untilT = os.clock() + (msg.seconds or (look.big and 3.2 or 2.6))
end

-- The join chips --------------------------------------------------------------------------------------------
local chips = {} -- { frame, untilT }
local CHIP_W, CHIP_H, CHIP_GAP, MAX_CHIPS = 250, 30, 6, 3

function NotifyController.chips()
	return chips
end

local function placeChips()
	for i, c in chips do
		Theme.tween(c.frame, 0.2, { Position = UDim2.new(0, 16, 0.4, (i - 1) * (CHIP_H + CHIP_GAP)) })
	end
end

local function chip(msg)
	local ally = msg.ally == true
	local color = typeof(msg.color) == "Color3" and msg.color or C.ink
	local f = Theme.new("Frame", {
		Name = "JoinChip",
		Position = UDim2.new(0, -CHIP_W, 0.4, #chips * (CHIP_H + CHIP_GAP)),
		Size = UDim2.fromOffset(CHIP_W, CHIP_H),
		BackgroundColor3 = ally and color or C.white,
		Parent = gui,
	}, { Theme.corner(15), Theme.stroke(2, color) })
	Theme.text({
		Name = "Text",
		Text = `{msg.icon or (ally and "🎉" or "⚔️")}  {string.upper(msg.text)}`,
		Size = UDim2.new(1, -16, 1, -4),
		Position = UDim2.fromOffset(8, 2),
		fit = 13,
		Font = Theme.Display,
		TextColor3 = ally and C.white or color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = f,
	})
	table.insert(chips, { frame = f, untilT = os.clock() + (msg.seconds or 4) })
	while #chips > MAX_CHIPS do
		table.remove(chips, 1).frame:Destroy()
	end
	placeChips()
	Theme.pop(f)
end

function NotifyController.show(msg)
	if type(msg) ~= "table" or type(msg.text) ~= "string" or msg.text == "" then
		return false
	end
	if msg.kind == "join" then
		if gui then
			chip(msg)
		end
		return true
	end
	table.insert(queue, msg)
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
	return true
end

local function step()
	if not strip then
		return
	end
	local now = os.clock()
	for i = #chips, 1, -1 do
		local c = chips[i]
		c.frame.Visible = not Layout.panel()
		if now >= c.untilT then
			table.remove(chips, i)
			local f = c.frame
			Theme.tween(f, 0.2, { Position = UDim2.new(0, -CHIP_W - 20, f.Position.Y.Scale, f.Position.Y.Offset) })
			task.delay(0.25, function()
				f:Destroy()
			end)
			placeChips()
		end
	end
	if Layout.panel() then
		strip.Visible = false
		return
	end
	local t = os.clock()
	if showing and t >= untilT then
		showing = nil
		Theme.tween(strip, 0.2, { Position = UDim2.new(0.5, 0, 0, 40) })
		task.delay(0.2, function()
			if not showing then
				strip.Visible = false
			end
		end)
	end
	if not showing and #queue > 0 then
		present(table.remove(queue, 1))
	elseif showing then
		strip.Visible = true
	end
end

function NotifyController:init()
	gui = Theme.screen("Notify", 12, Players.LocalPlayer:WaitForChild("PlayerGui"))
	strip = Theme.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(440, 44),
		BackgroundColor3 = C.ink,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(6), Theme.stroke(2, C.ink) })
	iconLabel = Theme.text({
		Name = "Icon",
		Text = "",
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = strip,
	})
	label = Theme.text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -56, 1, -8),
		Position = UDim2.fromOffset(46, 4),
		fit = 22,
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = strip,
	})
	NotifyController.refs = { gui = gui, strip = strip, label = label, icon = iconLabel }
	Net.listen("Announce", NotifyController.show)
	RunService.RenderStepped:Connect(step)
end

return NotifyController

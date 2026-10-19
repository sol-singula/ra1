--[[
The town's shared boost (master plan §11): a chip under the cash while one is on (what and how long), and the
BOOST panel: the meter, which boost is next, CHIP IN buttons, and the Robux way (the shop). The meter in the
square fills to match.

  BoostController.refs   chip, panel, fill (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local BoostController = { Name = "BoostController", Order = 61 }

local C = Theme.Color
local refs = {}
BoostController.refs = refs
local panel

local function paint()
	local b = Store.get("boost")
	if not b then
		return
	end
	local def = b.active and Shop.BOOSTS[b.active]
	refs.chip.Visible = def ~= nil
	if def then
		refs.chip.Text = `{def.icon} {def.name}: {Format.time(b.seconds or 0)}`
	end
	local k = b.cost > 0 and math.clamp(b.meter / b.cost, 0, 1) or 0
	refs.fill.Size = UDim2.fromScale(math.max(0.02, k), 1)
	refs.meterText.Text = def and `{def.name} is ON for everyone: {Format.time(b.seconds or 0)} left`
		or `{Format.cash(b.meter)} / {Format.cash(b.cost)} toward {Shop.BOOSTS[b.next] and Shop.BOOSTS[b.next].name or "the next boost"}`
	for _, btn in refs.chipIn do
		btn.Visible = def == nil
	end
	-- the meter in the square
	local town = workspace:FindFirstChild("Town")
	local fill = town and town:FindFirstChild("MeterFill")
	local tube = town and town:FindFirstChild("MeterTube")
	if fill and tube then
		local h = 0.2 + 11.6 * (def and 1 or k)
		fill.Size = Vector3.new(h, 3.2, 3.2)
		fill.CFrame = CFrame.new(tube.Position.X, 2 + h / 2, tube.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		fill.Color = def and def.color or Color3.fromRGB(255, 170, 40)
	end
end

function BoostController:init()
	local gui = Theme.screen("Boost", 6, game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
	refs.chip = Theme.text({
		Name = "Chip",
		Text = "",
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.fromOffset(300, 26),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		outline = 2,
		fit = 17,
		Visible = false,
		Parent = gui,
	})
	panel = Panel.new("boost", "SERVER BOOST", Color3.fromRGB(255, 170, 40), Vector2.new(560, 360))
	refs.panel = panel
	Theme.text({
		Text = "Everyone chips in Cash; full, the meter lights the next boost for the whole server, 10 minutes. The SHOP lights one at once.",
		Size = UDim2.new(1, 0, 0, 50),
		TextColor3 = C.muted,
		fit = 16,
		Parent = panel.body,
	})
	local bar, fill = Theme.bar(
		{ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 34), Parent = panel.body },
		Color3.fromRGB(255, 170, 40)
	)
	refs.bar, refs.fill = bar, fill
	refs.meterText = Theme.text({
		Name = "MeterText",
		Text = "",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 17,
		Parent = panel.body,
	})
	refs.chipIn = {}
	for k, amount in { 100, 500, 2500 } do
		local b = Theme.button({
			Name = "ChipIn" .. amount,
			Text = `CHIP IN {Format.cash(amount)}`,
			Position = UDim2.new((k - 1) / 3, 6, 0, 140),
			Size = UDim2.new(1 / 3, -12, 0, 48),
			BackgroundColor3 = C.good,
			Parent = panel.body,
		})
		b.Activated:Connect(function()
			Net.send("Boost", "contribute", amount)
		end)
		refs.chipIn[k] = b
	end
	local y = 206
	for _, key in Shop.BOOST_LIST do
		local def = Shop.BOOSTS[key]
		Theme.text({
			Text = `{def.icon} {def.name}: {def.desc}`,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 24),
			fit = 15,
			Parent = panel.body,
		})
		y += 26
	end
	panel.onOpen = function()
		Net.send("Boost", "open")
		paint()
	end
	Store.Changed:Connect(function(partial)
		if partial.boost then
			paint()
		end
	end)
	-- the countdown ticks on its own between pushes
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			local b = Store.get("boost")
			if b and b.active and b.seconds then
				b.seconds = math.max(0, b.seconds - 1)
				paint()
			end
		end
	end)
	-- the plinth's prompt opens the panel
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "Boost" then
			Bus.Panel:Fire("boost")
		end
	end)
end

return BoostController

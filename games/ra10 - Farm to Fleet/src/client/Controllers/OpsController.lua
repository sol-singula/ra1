--[[
The Operations strip (master plan §13.2): once the warehouse stands, a panel under the money shows the four
stations (GROW, PACK, STORE, SHIP) as bars of Cash-a-minute, the slowest one red with BOTTLENECK, how full the
racks are and the operation's size. Net "Flow" fills it.

  OpsController.state()   the last Net "Flow"
  OpsController.refs      the panel's pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local OpsController = { Name = "OpsController", Order = 46 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = { rows = {} }
OpsController.refs = refs
local state = {}

local STATIONS = { { "grow", "GROW" }, { "pack", "PACK" }, { "store", "STORE" }, { "ship", "SHIP" } }
local RED = Color3.fromRGB(240, 70, 60)
local GREEN = Color3.fromRGB(80, 210, 120)

function OpsController.state()
	return state
end

local function paint()
	refs.panel.Visible = state.open == true
	if not state.open then
		return
	end
	local rates = state.rates or {}
	local top = 1
	for _, s in STATIONS do
		top = math.max(top, rates[s[1]] or 0)
	end
	for i, s in STATIONS do
		local r = refs.rows[i]
		local red = state.bottleneck == s[1]
		local v = rates[s[1]] or 0
		r.name.Text = s[2]
		r.name.TextColor3 = red and RED or C.white
		r.fill.BackgroundColor3 = red and RED or GREEN
		r.fill.Size = UDim2.fromScale(math.clamp(v / top, 0.04, 1), 1)
		r.rate.Text = Format.num(v) .. "/min"
		r.rate.TextColor3 = red and RED or C.white
	end
	local b = state.bottleneck and string.upper(state.bottleneck) or ""
	refs.alert.Text = state.full and "RACKS FULL: buy racks at STORE" or `BOTTLENECK: {b}`
	refs.stock.Text = `Racks {state.racked or 0}/{state.slots or 0} · Size {Format.num(state.size or 0)}`
end

function OpsController:init()
	local gui = Theme.screen("Ops", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	refs.panel = Theme.slab({
		Name = "Ops",
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.fromOffset(250, 160),
		Visible = false,
		Parent = gui,
	})
	refs.title = Theme.text({
		Name = "Title",
		Text = "OPERATIONS",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		fit = 18,
		Parent = refs.panel,
	})
	for i = 1, 4 do
		local y = 30 + (i - 1) * 24
		local r = {}
		r.name = Theme.text({
			Name = "Name" .. i,
			Text = "",
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.fromOffset(52, 20),
			Font = Theme.Display,
			fit = 14,
			Parent = refs.panel,
		})
		local bar = Theme.new("Frame", {
			Name = "Bar" .. i,
			Position = UDim2.fromOffset(64, y + 4),
			Size = UDim2.fromOffset(100, 12),
			BackgroundColor3 = Color3.fromRGB(50, 58, 70),
			BorderSizePixel = 0,
			Parent = refs.panel,
		}, { Theme.corner(4) })
		r.fill = Theme.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0.5, 1),
			BackgroundColor3 = GREEN,
			BorderSizePixel = 0,
			Parent = bar,
		}, { Theme.corner(4) })
		r.rate = Theme.text({
			Name = "Rate" .. i,
			Text = "",
			Position = UDim2.fromOffset(168, y),
			Size = UDim2.fromOffset(74, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			fit = 14,
			Parent = refs.panel,
		})
		refs.rows[i] = r
	end
	refs.alert = Theme.text({
		Name = "Alert",
		Text = "",
		Position = UDim2.fromOffset(10, 126),
		Size = UDim2.new(1, -20, 0, 16),
		Font = Theme.Display,
		TextColor3 = RED,
		fit = 13,
		Parent = refs.panel,
	})
	refs.stock = Theme.text({
		Name = "Stock",
		Text = "",
		Position = UDim2.fromOffset(10, 142),
		Size = UDim2.new(1, -20, 0, 14),
		TextColor3 = C.grey,
		fit = 12,
		Parent = refs.panel,
	})
	Net.listen("Flow", function(m)
		if type(m) ~= "table" then
			return
		end
		state = m
		paint()
	end)
end

return OpsController

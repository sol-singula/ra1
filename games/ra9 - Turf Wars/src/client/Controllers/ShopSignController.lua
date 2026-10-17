--[[
The shop sign on each spawn deck. ArenaBuilder stands a plain board there (white and grey with the team's colour,
by the deck's side wall, clear of the pads and the cover; looks only: no body, arrow or piece is ever stopped by it);
this puts the words and the prompt on it, on this client only:

  "🛒 SHOP" big, and under it today's deal (its item, how much off, the clock) or "NEW ITEMS EVERY DAY"
  a prompt: walk up and press it (E on a keyboard or a click on it, X on a gamepad, a tap on a phone) and the shop
  opens at its top, the deal first (PanelController.showDeal, from = "deck_sign")

Only in the build phase, and only on your own team's deck (never in the tutorial's practice).

  ShopSignController.signs()    { [team] = { board, gui, prompt } } the boards found
  ShopSignController.open()     what the prompt does
  ShopSignController.update()   the words, and who sees them (stepped a few times a second; tests call it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local PanelController = require(script.Parent.PanelController)

-- (a match's: not in the lobby, which has its own screens)
local ShopSignController = { Name = "ShopSignController", Order = 60, Modes = { "turf", "ctf", "brawl" } }

local C = Theme.Color
local player = Players.LocalPlayer
local signs = {} -- [team] = { board, gui, prompt, title, line }
local arena -- the arena folder the signs were found in

function ShopSignController.open()
	return PanelController.showDeal("deck_sign")
end

-- The words over a board (a billboard: readable from anywhere on the deck) and its prompt
local function dress(board, team)
	local color = Constants.TEAM_COLOR[team] or C.ink
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShopSignWords"
	gui.Size = UDim2.fromScale(6, 3.2) -- (in studs: about the board's size)
	gui.StudsOffset = Vector3.new(0, 0.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Adornee = board
	gui.Enabled = false
	local card = Theme.new("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Theme.corner(6), Theme.stroke(3, color) })
	local title = Theme.new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(0.9, 0.52),
		BackgroundTransparency = 1,
		Text = "🛒 SHOP",
		TextScaled = true,
		Font = Theme.Display,
		TextColor3 = C.ink,
		Parent = card,
	})
	local line = Theme.new("TextLabel", {
		Name = "Line",
		Position = UDim2.fromScale(0.05, 0.6),
		Size = UDim2.fromScale(0.9, 0.32),
		BackgroundTransparency = 1,
		Text = "",
		TextScaled = true,
		Font = Theme.Display,
		TextColor3 = color,
		Parent = card,
	})
	gui.Parent = board
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "🛒 SHOP"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Enabled = false
	prompt.Parent = board
	prompt.Triggered:Connect(function()
		ShopSignController.open()
	end)
	return { board = board, gui = gui, prompt = prompt, title = title, line = line }
end

-- The boards in the arena now (a new match builds a new arena: dressed again)
local function find()
	local a = workspace:FindFirstChild("Arena")
	if a == arena and a ~= nil then
		return
	end
	arena = a
	for _, s in signs do
		if s.gui.Parent then
			s.gui:Destroy()
			s.prompt:Destroy()
		end
	end
	table.clear(signs)
	if not a then
		return
	end
	for _, d in a:GetDescendants() do
		if d.Name == "ShopSign" and d:IsA("BasePart") then
			local team = d:GetAttribute("Team")
			if team and not signs[team] then
				signs[team] = dress(d, team)
			end
		end
	end
end

-- Today's deal, in a line: "⚡ 70% OFF NEON TRAIL · 41:12", or the daily rotation when there's none
local function dealLine()
	local key = player:GetAttribute("Deal")
	local ends = tonumber(player:GetAttribute("DealEnds"))
	local d = type(key) == "string" and Shop.products[key]
	local it = d and Cosmetics.get(d.cosmetic)
	local left = ends and ends - workspace:GetServerTimeNow() or 0
	if it and left > 0 then
		return `⚡ {math.floor(Shop.DEAL.off * 100 + 0.5)}% OFF {string.upper(it.name)} · {PanelController.clock(left)}`
	end
	return "NEW ITEMS EVERY DAY"
end

function ShopSignController.update()
	find()
	local mine = Store.team()
	local on = Store.phase() == "build" and not Layout.inPractice()
	local words = on and dealLine() or ""
	for team, s in signs do
		local show = on and team == mine
		s.gui.Enabled = show
		s.prompt.Enabled = show
		if show then
			s.line.Text = words
		end
	end
end

function ShopSignController.signs()
	return signs
end

function ShopSignController:init()
	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t < nextAt then
			return
		end
		nextAt = t + 0.25
		ShopSignController.update()
	end)
end

return ShopSignController

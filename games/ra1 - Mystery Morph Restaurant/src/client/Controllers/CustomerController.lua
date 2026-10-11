-- Client visual side of SPCV customers (GDD §27.12.4, reduced): builds a body for every customer proxy,
-- interpolates it toward the proxy, shows a head-top bubble (order, patience, anger, Huff Points) and keeps
-- the ticket rail at the top of the screen in sync with the player's own customers.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MorphBuilder = require(ReplicatedStorage.Shared.MorphBuilder)
local Personalities = require(ReplicatedStorage.Shared.Data.Personalities)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local CustomerController = { Name = "CustomerController", Order = 40 }

local visuals = {} -- [proxy] = { model, root, bubble refs }
local folder, ticketGui, ticketRail
local ticketsDirty = true

local ANGER_FACE = { "😊", "😐", "😒", "😠", "🤬", "💢", "🔥" }
local MOOD_FACE = { Delighted = "😍", Happy = "😋", Meh = "😐", Unhappy = "😕", Furious = "😡" }

local function decodeOrder(proxy)
	local raw = proxy:GetAttribute("Order")
	if not raw then
		return nil
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and list or nil
end

local function buildBubble(v)
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(200, 120),
		StudsOffset = Vector3.new(0, 4.6, 0),
		AlwaysOnTop = false,
		MaxDistance = 60,
		Adornee = v.root,
		Parent = v.model,
	})
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bb }, {
		new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 3),
		}),
	})
	local speech = Theme.card({
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = holder,
	})
	Theme.padding(6).Parent = speech
	local speechText = Theme.text({
		Text = "",
		TextSize = 14,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = speech,
	})
	local status =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 22), LayoutOrder = 2, Parent = holder })
	local face = Theme.text({
		Text = "😊",
		Size = UDim2.fromOffset(22, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = status,
	})
	local patience, patienceFill =
		Theme.bar({ Size = UDim2.new(1, -28, 0, 10), Position = UDim2.fromOffset(28, 6), Parent = status }, C.good)
	local huff, huffFill = Theme.bar({ Size = UDim2.fromOffset(150, 8), LayoutOrder = 3, Parent = holder }, C.ketchup)
	v.bubble = {
		speech = speech,
		speechText = speechText,
		face = face,
		patience = patience,
		patienceFill = patienceFill,
		huff = huff,
		huffFill = huffFill,
	}
end

local function refreshBubble(v, proxy)
	local b = v.bubble
	local state = proxy:GetAttribute("State")
	local level = proxy:GetAttribute("AngerLevel") or 0
	local p = proxy:GetAttribute("Patience") or 1
	local mood = proxy:GetAttribute("Mood")
	b.face.Text = mood and MOOD_FACE[mood] or ANGER_FACE[level + 1]
	local text
	if state == "ORDER" then
		text = "Ready to order!"
	elseif state == "QUEUE" then
		text = "Waiting in line…"
	elseif state == "DIZZY" then
		text = "@_@"
	elseif state == "EAT" then
		text = mood and `{mood}! nom nom` or "nom nom"
	elseif state == "TO_SEAT" or state == "WAIT_FOOD" or state == "CHASE" then
		local lines = {}
		for _, item in decodeOrder(proxy) or {} do
			table.insert(
				lines,
				(item.served and "✓ " or "• ") .. item.name .. (item.mod and `\n  “{item.mod}”` or "")
			)
		end
		text = table.concat(lines, "\n")
	end
	b.speech.Visible = text ~= nil and text ~= ""
	b.speechText.Text = text or ""
	local showPatience = state == "ORDER" or state == "QUEUE" or state == "WAIT_FOOD" or state == "TO_SEAT"
	b.patience.Visible = showPatience
	b.patienceFill.Size = UDim2.fromScale(p, 1)
	b.patienceFill.BackgroundColor3 = p > 0.5 and C.good or (p > 0.2 and C.mustard or C.ketchup)
	local huff, huffMax = proxy:GetAttribute("Huff") or 1, proxy:GetAttribute("HuffMax") or 1
	b.huff.Visible = huff < huffMax
	b.huffFill.Size = UDim2.fromScale(math.clamp(huff / huffMax, 0, 1), 1)
end

local function add(proxy)
	if visuals[proxy] then
		return
	end
	local personality = Personalities[proxy:GetAttribute("Personality")]
	if not personality then
		return
	end
	local model = MorphBuilder.buildCustomer(personality, proxy:GetAttribute("Seed") or 1)
	model:PivotTo(proxy.CFrame)
	model.Parent = folder
	local v = { model = model, root = model.PrimaryPart, cf = proxy.CFrame, bob = math.random() * 10 }
	visuals[proxy] = v
	buildBubble(v)
	refreshBubble(v, proxy)
	proxy.AttributeChanged:Connect(function()
		if visuals[proxy] then
			refreshBubble(v, proxy)
			ticketsDirty = true
		end
	end)
	ticketsDirty = true
end

local function remove(proxy)
	local v = visuals[proxy]
	if v then
		v.model:Destroy()
		visuals[proxy] = nil
		ticketsDirty = true
	end
end

local function step(dt)
	local alpha = 1 - math.exp(-14 * dt)
	for proxy, v in visuals do
		if not proxy.Parent then
			remove(proxy)
		else
			v.cf = v.cf:Lerp(proxy.CFrame, alpha)
			local state = proxy:GetAttribute("State")
			local offset = CFrame.identity
			v.bob += dt * 10
			if state == "WAIT_FOOD" or state == "EAT" then
				offset = CFrame.new(0, -0.9 + (state == "EAT" and math.abs(math.sin(v.bob)) * 0.15 or 0), 0) -- sitting
			elseif state == "DIZZY" then
				offset = CFrame.Angles(0, v.bob * 0.6, 0)
			elseif (v.cf.Position - proxy.Position).Magnitude > 0.05 then
				offset = CFrame.new(0, math.abs(math.sin(v.bob)) * 0.25, 0) -- walking bounce
			end
			v.root.CFrame = v.cf * offset
		end
	end
end

-- Ticket rail ------------------------------------------------------------------------------------------
local function rebuildTickets()
	ticketsDirty = false
	for _, child in ticketRail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local mine = {}
	for proxy in visuals do
		local state = proxy:GetAttribute("State")
		if
			proxy:GetAttribute("OwnerUserId") == player.UserId
			and (state == "TO_SEAT" or state == "WAIT_FOOD" or state == "CHASE")
		then
			table.insert(mine, proxy)
		end
	end
	table.sort(mine, function(a, b)
		return (a:GetAttribute("CustomerId") or 0) < (b:GetAttribute("CustomerId") or 0)
	end)
	for i, proxy in mine do
		local items = decodeOrder(proxy) or {}
		local personality = Personalities[proxy:GetAttribute("Personality")]
		local card = Theme.card({
			Size = UDim2.fromOffset(170, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = ticketRail,
		})
		Theme.padding(6).Parent = card
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
		Theme.text({
			Text = "ORDER",
			Font = Theme.Display,
			TextColor3 = C.ketchup,
			TextSize = 16,
			TextScaled = false,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 0,
			Parent = card,
		})
		Theme.text({
			Text = personality and personality.name or "",
			TextColor3 = C.muted,
			TextSize = 12,
			TextScaled = false,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 1,
			Parent = card,
		})
		for j, item in items do
			local line = (item.served and "✓ " or "") .. item.name .. (item.mod and `\n“{item.mod}”` or "")
			Theme.text({
				Text = line,
				TextSize = 13,
				TextScaled = false,
				TextColor3 = item.served and C.muted or C.ink,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = 1 + j,
				Parent = card,
			})
		end
		local p = proxy:GetAttribute("Patience") or 1
		local _, fill = Theme.bar(
			{ Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 99, Parent = card },
			p > 0.5 and C.good or (p > 0.2 and C.mustard or C.ketchup)
		)
		fill.Size = UDim2.fromScale(p, 1)
	end
end

function CustomerController:init()
	folder = new("Folder", { Name = "ClientCustomers", Parent = workspace })
	ticketGui = new("ScreenGui", { Name = "Tickets", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	ticketRail = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(1, -700, 0, 200),
		Parent = ticketGui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})

	CollectionService:GetInstanceAddedSignal("MMR_Customer"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("MMR_Customer"):Connect(remove)
	for _, proxy in CollectionService:GetTagged("MMR_Customer") do
		add(proxy)
	end
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if ticketsDirty then
				rebuildTickets()
			end
		end
	end)
end

return CustomerController

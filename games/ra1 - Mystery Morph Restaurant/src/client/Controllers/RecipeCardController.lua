-- The recipe card: for the oldest order you still owe, lists what the dish needs, how to prep each part, and ticks
-- off what's already stacked on an Assembly Counter board. Drinks just point at the Drink Dispenser.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Data.Ingredients)
local Personalities = require(ReplicatedStorage.Shared.Data.Personalities)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local RecipeCardController = { Name = "RecipeCardController", Order = 45 }

local PREP = {
	GRILLED = { icon = "🔥", how = "Grill" },
	FRIED = { icon = "🍟", how = "Fryer" },
	CHOPPED = { icon = "🔪", how = "Cutting Board" },
	RAW = { icon = "📦", how = "Pantry" },
}

local gui, card

local function decode(raw)
	if not raw then
		return nil
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and v or nil
end

local function myBoards()
	local folder = workspace:FindFirstChild("Restaurants")
	if not folder then
		return {}
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("OwnerUserId") == player.UserId then
			local assembly = model:FindFirstChild("Stations") and model.Stations:FindFirstChild("STN_ASSEMBLY")
			if assembly then
				local list = {}
				for i = 1, 2 do
					local b = assembly:FindFirstChild("Board" .. i)
					if b then
						table.insert(list, decode(b:GetAttribute("Contents")) or {})
					end
				end
				return list
			end
		end
	end
	return {}
end

-- oldest seated customer of mine with something unserved, and that item
local function nextOrder()
	local best, bestId, bestItem
	for _, proxy in CollectionService:GetTagged("MMR_Customer") do
		local state = proxy:GetAttribute("State")
		if
			proxy:GetAttribute("OwnerUserId") == player.UserId
			and (state == "TO_SEAT" or state == "WAIT_FOOD" or state == "CHASE")
		then
			for _, item in decode(proxy:GetAttribute("Order")) or {} do
				local id = proxy:GetAttribute("CustomerId") or 0
				if not item.served and (not best or id < bestId) then
					best, bestId, bestItem = proxy, id, item
					break
				end
			end
		end
	end
	return best, bestItem
end

local lastSignature

-- Work out the card's lines; only rebuild the UI when they change.
local function render()
	local proxy, item = nextOrder()
	local recipe = item and item.id and Recipes.byId[item.id]
	local lines = {}
	local function line(text, props)
		table.insert(lines, { text = text, props = props })
	end
	if recipe then
		local who = Personalities[proxy:GetAttribute("Personality")]
		line("RECIPE CARD", { Font = Theme.Display, TextColor3 = C.ketchup, TextSize = 18 })
		line(`{recipe.name}  ·  for {who and who.name or "a customer"}`, { TextSize = 19 })
		if recipe.drink then
			line("🥤 Pour it at the Drink Dispenser. Stop in the green band.")
		else
			-- the board with the most progress toward this recipe
			local contents, bestScore = {}, -1
			for _, b in myBoards() do
				local score = 0
				for _, part in recipe.parts do
					score += math.min(b[part[1] .. "|" .. part[3]] or 0, part[2])
				end
				if score > bestScore then
					bestScore, contents = score, b
				end
			end
			local omit = item.omit or {}
			for _, part in recipe.parts do
				local id, count, state = part[1], part[2], part[3]
				local prep = PREP[state]
				local have = contents[id .. "|" .. state] or 0
				local name = Ingredients[id].name .. (count > 1 and ` ×{count}` or "")
				if table.find(omit, id) then
					line(`🚫 No {Ingredients[id].name} (they asked)`, { TextColor3 = C.muted })
				elseif have >= count then
					line(`✅ {name}`, { TextColor3 = Color3.fromRGB(30, 140, 70) })
				else
					line(`{prep.icon} {name}  →  {prep.how}{have > 0 and ` ({have}/{count})` or ""}`)
				end
			end
			line("Stack everything on a board, then press E on it to plate.", { TextColor3 = C.muted, TextSize = 15 })
		end
	end
	local texts = {}
	for _, l in lines do
		table.insert(texts, l.text)
	end
	local signature = table.concat(texts, "\n")
	if signature == lastSignature then
		return
	end
	lastSignature = signature
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	card.Visible = #lines > 0
	for i, l in lines do
		local props = {
			Text = l.text,
			TextSize = 17,
			TextScaled = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = i,
			Parent = card,
		}
		for k, v in l.props or {} do
			props[k] = v
		end
		Theme.text(props)
	end
end

function RecipeCardController:init()
	gui = new("ScreenGui", { Name = "RecipeCard", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	card = Theme.card({
		Name = "Card",
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -346, 0, 112),
		Visible = false,
		Parent = gui,
	})
	Theme.padding(12).Parent = card
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	task.spawn(function()
		while true do
			local ok, err = pcall(render)
			if not ok then
				warn("[RecipeCard] " .. tostring(err))
			end
			task.wait(0.4)
		end
	end)
end

return RecipeCardController

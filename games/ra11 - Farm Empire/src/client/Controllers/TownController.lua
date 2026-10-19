--[[
The town's boards: the three leaderboards in the square painted from Net "Leaderboards" (all-time earned,
regions, units sold), and the store's "coming soon" prompt (nothing is sold there yet).

  TownController.painted()   how many rows are on the boards (tests)
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TownController = { Name = "TownController", Order = 64 }

local TITLES = { earned = "TOP EARNERS", regions = "MOST REGIONS", sold = "MOST SOLD" }
local guis = {}
local rows = 0

function TownController.painted()
	return rows
end

local function boardGui(plate, key)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Board"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 200, 36)
	title.Text = TITLES[key] or key
	title.Parent = sg
	for i = 1, 10 do
		local l = Instance.new("TextLabel")
		l.Name = "Row" .. i
		l.BackgroundTransparency = 1
		l.Position = UDim2.new(0.04, 0, 0.14 + (i - 1) * 0.085, 0)
		l.Size = UDim2.new(0.92, 0, 0.08, 0)
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(255, 255, 255)
		l.Text = ""
		l.Parent = sg
	end
	sg.Parent = plate
	return sg
end

local function paint()
	local boards = Store.get("leaderboards")
	local town = workspace:FindFirstChild("Town")
	if not boards or not town then
		return
	end
	rows = 0
	for _, plate in town:GetDescendants() do
		if plate.Name == "Leaderboard" and plate:IsA("BasePart") then
			local key = plate:GetAttribute("Board")
			local gui = guis[plate] or boardGui(plate, key)
			guis[plate] = gui
			local list = boards[key] or {}
			for i = 1, 10 do
				local r = list[i]
				local l = gui:FindFirstChild("Row" .. i)
				if l then
					if r then
						rows += 1
						local v = key == "regions" and tostring(r.value) or Format.cash(r.value)
						if key == "sold" then
							v = Format.num(r.value)
						end
						l.Text = `{i}. {r.name or "?"}  {v}`
					else
						l.Text = ""
					end
				end
			end
		end
	end
end

function TownController:init()
	Store.Changed:Connect(function(partial)
		if partial.leaderboards then
			paint()
		end
	end)
	paint()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "Store" then
			local Hud = require(script.Parent.HudController)
			Hud.toast("The store opens soon! Keep growing your empire.", "good")
		end
	end)
	_ = Theme
end

return TownController

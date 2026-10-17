--[[
The first knockout: until you've knocked anyone out (the server's "Novice" attribute, CombatService:Novice), the
nearest enemy in the fight is marked: a bright outline round them and a bobbing "🎯 GET THEM!" over their head. Your
shots at anyone near them are helped onto them by the server, so the first one lands. The mark goes the moment you
score (the attribute clears), and it's never there in the build phase or while you're down.

  FirstTargetController.target()   the body marked now (tests), or nil
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Store = require(script.Parent.Parent.Store)

local FirstTargetController = { Name = "FirstTargetController", Order = 91 }

local player = Players.LocalPlayer
local marked -- the character marked
local highlight, tag

local function clear()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if tag then
		tag:Destroy()
		tag = nil
	end
	marked = nil
end

local function enemies()
	local mine = player:GetAttribute("Team")
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character and p:GetAttribute("Team") ~= nil and p:GetAttribute("Team") ~= mine then
			table.insert(out, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, c in bots and bots:GetChildren() or {} do
		if c:GetAttribute("Team") ~= nil and c:GetAttribute("Team") ~= mine then
			table.insert(out, c)
		end
	end
	return out
end

local function mark(c)
	if marked == c then
		return
	end
	clear()
	marked = c
	local ok = pcall(function()
		highlight = Instance.new("Highlight")
		highlight.Name = "FirstTarget"
		highlight.FillTransparency = 0.75
		highlight.FillColor = Color3.fromRGB(255, 230, 60)
		highlight.OutlineColor = Color3.fromRGB(255, 230, 60)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = c
		highlight.Parent = c
	end)
	if not ok then
		highlight = nil
	end
	local head = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
	tag = Instance.new("BillboardGui")
	tag.Name = "FirstTargetTag"
	tag.Size = UDim2.fromOffset(150, 40)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = head
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "🎯 GET THEM!"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 230, 60)
	l.TextStrokeTransparency = 0.2
	l.Parent = tag
	tag.Parent = c
end

function FirstTargetController.target()
	return marked
end

function FirstTargetController.update()
	local me = Store.get("me")
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("Novice") ~= true or Store.phase() ~= "fight" or not (me and me.alive) or not r then
		clear()
		return nil
	end
	local best, bestD
	for _, e in enemies() do
		local er = e:FindFirstChild("HumanoidRootPart")
		if er then
			local d = (er.Position - r.Position).Magnitude
			if d <= Constants.FIRST_KILL_RANGE and (not bestD or d < bestD) then
				best, bestD = e, d
			end
		end
	end
	if best then
		mark(best)
		if tag then
			tag.StudsOffset = Vector3.new(0, 3.4 + math.abs(math.sin(os.clock() * 4)) * 0.6, 0)
		end
	else
		clear()
	end
	return best
end

function FirstTargetController:init()
	task.spawn(function()
		while true do
			task.wait(0.2)
			pcall(FirstTargetController.update)
		end
	end)
end

return FirstTargetController

--[[
The world leaderboards: Workspace.Street.Boards.ServerBoard (everyone in this server by garden value) and
GlobalBoard (the weekly top 100), each a SurfaceGui drawn here from the ReplicatedStorage.Leaderboards attributes
(Server, Global: JSON rows { userId, name, value }; UpdateId; ResetAt). Each shows your rank and when it resets, in
local time.

  LeaderboardController.rows(which)      "Server" | "Global" -> the decoded rows
  LeaderboardController.rankOf(rows, userId)
  LeaderboardController.refresh()
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local UI = require(script.Parent.Parent.UI)

local LeaderboardController = {}

local SHOW = { Server = 10, Global = 10 }
local TITLES = { Server = "🏡 This server", Global = "🏆 Top 100 this week" }

local controllers
local surfaces = {}

local function folder()
	return ReplicatedStorage:FindFirstChild("Leaderboards")
end

function LeaderboardController.rows(which)
	local f = folder()
	local raw = f and f:GetAttribute(which)
	if type(raw) ~= "string" then
		return {}
	end
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(rows) == "table" then rows else {}
end

function LeaderboardController.rankOf(rows, userId)
	for i, row in rows do
		if row.userId == userId then
			return i
		end
	end
	return nil
end

local function resetText()
	local f = folder()
	local at = f and f:GetAttribute("ResetAt")
	if not at then
		return ""
	end
	return `Resets {controllers.HudController.localDayTime(at)} (in {UI.duration(at - Clock.now())})`
end

local function draw(which)
	local gui = surfaces[which]
	if not gui then
		return
	end
	local body = gui.Body
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	UI.label(body, TITLES[which], { Name = "Title", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40) })
	local rows = LeaderboardController.rows(which)
	for i = 1, math.min(#rows, SHOW[which]) do
		local row = rows[i]
		UI.label(body, `{i}. {row.name} · {UI.money(row.value)}`, {
			Name = "Row" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, -16, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local rank = LeaderboardController.rankOf(rows, Players.LocalPlayer.UserId)
	UI.label(body, if rank then `You: #{rank}` else "You: not ranked yet", {
		Name = "You",
		LayoutOrder = 50,
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = UI.COLORS.green,
	})
	UI.label(body, resetText(), { Name = "Reset", LayoutOrder = 51, Size = UDim2.new(1, 0, 0, 26) })
end

function LeaderboardController.refresh()
	draw("Server")
	draw("Global")
end

local function build(which, part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = which .. "BoardSurface"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	local body = UI.frame(gui, { Name = "Body", Size = UDim2.fromScale(1, 1) })
	UI.list(body, 4)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	surfaces[which] = gui
end

function LeaderboardController:Init(all)
	controllers = all
end

function LeaderboardController:Start()
	local street = workspace:FindFirstChild("Street")
	local boards = street and street:FindFirstChild("Boards")
	for _, which in { "Server", "Global" } do
		local part = boards and boards:FindFirstChild(which .. "Board")
		if part then
			build(which, part)
		end
	end
	local function watch(f)
		for _, which in { "Server", "Global" } do
			f:GetAttributeChangedSignal(which):Connect(function()
				draw(which)
			end)
		end
		LeaderboardController.refresh()
	end
	task.spawn(function()
		local f = folder()
		while not f do
			task.wait(1)
			f = folder()
		end
		watch(f)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, gui in surfaces do
				local reset = gui.Body:FindFirstChild("Reset")
				if reset then
					reset.Text = resetText()
				end
			end
		end
	end)
end

return LeaderboardController

--[[
The weekly update board: a world board by Patch (Workspace.Street.Boards.UpdateBoard, a SurfaceGui drawn here) and the
same content in a HUD view. Both show the banner, What's new (WeeklyState.notes), Claim for this update's gift
(Weekly:claim {updateId}) and the next update in local time. The board's "View" prompt opens the HUD view; the FTUE
"board" toast points the HUD at it with the next update and the next Block Party in local time.

  UpdateBoardController.open() / close() / isOpen() / fill()
  UpdateBoardController.state()      the last WeeklyState
  UpdateBoardController.set(state)
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local UpdateBoardController = {}

local controllers
local modal, surface
local current

function UpdateBoardController.state()
	return current
end

local function claim()
	if current and not current.claimed then
		Net.request("Weekly", "claim", { updateId = current.updateId })
	end
end

-- draws the update into a container (the HUD body or the world board)
local function draw(parent, compact)
	if not current then
		UI.label(parent, "Loading the update...", { Name = "Banner" })
		return
	end
	local hud = controllers.HudController
	local notes = current.notes or {}
	UI.label(parent, (if current.eventWeek then "🌙 Event week! " else "📰 ") .. (notes.title or "This week"), {
		Name = "Banner",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = UI.COLORS.green,
	})
	for i, line in notes.lines or {} do
		UI.label(parent, "• " .. line, {
			Name = "Note" .. i,
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, if compact then 26 else 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
	end
	if current.claimed then
		UI.label(
			parent,
			"✓ Update gift claimed",
			{ Name = "Claimed", LayoutOrder = 20, TextColor3 = UI.COLORS.green }
		)
	else
		UI.button(parent, "Claim your update gift", claim, { Name = "Claim", LayoutOrder = 20 })
	end
	UI.label(
		parent,
		`Next update {hud.localDayTime(current.nextAt)} (in {UI.duration(current.nextAt - Clock.now())})`,
		{
			Name = "Next",
			LayoutOrder = 21,
			Size = UDim2.new(1, 0, 0, 26),
		}
	)
end

local function clear(container)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

function UpdateBoardController.fill()
	modal.clear()
	draw(modal.body, false)
	if surface then
		local body = surface:FindFirstChild("Body")
		clear(body)
		draw(body, true)
	end
end

function UpdateBoardController.set(state)
	if type(state) ~= "table" then
		return
	end
	current = state
	UpdateBoardController.fill()
end

function UpdateBoardController.open()
	UpdateBoardController.fill()
	modal.open()
	local button = controllers.HudController.rewards and controllers.HudController.rewards:FindFirstChild("Update")
	if button then
		button:SetAttribute("Pointing", false)
	end
end

function UpdateBoardController.close()
	modal.close()
end

function UpdateBoardController.isOpen()
	return modal.isOpen()
end

local function board()
	local street = workspace:FindFirstChild("Street")
	local boards = street and street:FindFirstChild("Boards")
	return boards and boards:FindFirstChild("UpdateBoard")
end

local function buildSurface(part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "UpdateBoardSurface"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	local body = UI.frame(gui, { Name = "Body", Size = UDim2.fromScale(1, 1) })
	UI.list(body, 6)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	return gui
end

-- the FTUE beat: point the HUD at the board
local function pointAtBoard(data)
	local hud = controllers.HudController
	local button = hud.rewards and hud.rewards:FindFirstChild("Update")
	if button then
		button:SetAttribute("Pointing", true)
	end
	local text = "📰 Check the update board!"
	if data and data.nextUpdateAt then
		text ..= ` Next update {hud.localDayTime(data.nextUpdateAt)}`
	end
	if data and data.nextPartyAt then
		text ..= ` · 🌻 {hud.localTime(data.nextPartyAt)}`
	end
	hud.toast(text, { "Open", UpdateBoardController.open })
end

function UpdateBoardController:Init(all)
	controllers = all
end

function UpdateBoardController:Start()
	modal = UI.modal("UpdateBoard", "Weekly Update")
	modal.card.Size = UDim2.fromOffset(500, 460)
	local part = board()
	if part then
		surface = buildSurface(part)
	end
	Net.on("WeeklyState", UpdateBoardController.set)
	Net.on("Toast", function(t)
		if type(t) == "table" and t.kind == "board" then
			pointAtBoard(t.data)
		end
	end)
	ClientState.Changed:Connect(function(roots)
		if roots == nil and ClientState.extra and ClientState.extra.weekly then
			UpdateBoardController.set(ClientState.extra.weekly)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "View" and prompt.Parent and prompt.Parent.Name == "UpdateBoard" then
			UpdateBoardController.open()
		end
	end)
	UpdateBoardController.fill()
	task.spawn(function()
		while true do
			task.wait(1)
			local next = surface and surface.Body:FindFirstChild("Next")
			if current and next then
				next.Text = `Next update {controllers.HudController.localDayTime(current.nextAt)} (in {UI.duration(
					current.nextAt - Clock.now()
				)})`
				if modal.isOpen() then
					modal.body.Next.Text = next.Text
				end
			end
		end
	end)
end

return UpdateBoardController

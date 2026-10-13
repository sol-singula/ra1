-- The Bonk Arena screen (only in the arena): your KOs at the top, a big BONK button on phones, Q / R2 to bonk,
-- and a "BONKED by ...!" card with a countdown until you respawn.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local BonkController = require(script.Parent.BonkController)

local C = Theme.Color
local player = Players.LocalPlayer

local ArenaController = { Name = "ArenaController", Order = 30 }

local gui, koLabel, downCard, downText, toastLabel

local function bonk()
	if BonkController.localSwing() then
		Net.send("Bonk")
	end
end

function ArenaController.kos()
	local stats = player:FindFirstChild("leaderstats")
	local ko = stats and stats:FindFirstChild("KOs")
	return ko and ko.Value or 0
end

function ArenaController:init()
	gui = Theme.screen("Arena", 3, player:WaitForChild("PlayerGui"))
	local top = Theme.slab({
		Name = "Score",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 56),
		Position = UDim2.new(0.5, 0, 0, 10),
		round = true,
		Parent = gui,
	})
	koLabel = Theme.title({
		Name = "KOs",
		Text = "⚔️ BONK ARENA · 0 KOs",
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		Parent = top,
	})
	downCard = Theme.slab({
		Name = "Bonked",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(460, 110),
		Position = UDim2.fromScale(0.5, 0.4),
		Visible = false,
		round = true,
		Parent = gui,
	})
	downCard.BackgroundColor3 = C.red
	downText = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		Parent = downCard,
	})
	toastLabel = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(560, 30),
		Position = UDim2.new(0.5, 0, 1, -110),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	-- the bonk button (phones and tablets) and keys
	if Theme.inputKind() == "touch" then
		local button = Theme.button({
			Name = "BonkButton",
			Text = "🔨 BONK",
			BackgroundColor3 = C.red,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(120, 120),
			Position = UDim2.new(1, -150, 1, -40),
			round = true,
			Parent = gui,
		})
		button.Activated:Connect(bonk)
	end
	ContextActionService:BindAction("ArenaBonk", function(_, state)
		if state == Enum.UserInputState.Begin then
			bonk()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
	Net.listen("ArenaKO", function(info)
		local by = type(info) == "table" and info.by or "someone"
		local seconds = type(info) == "table" and info.respawn or 1.5
		downCard.Visible = true
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < seconds do
				downText.Text = `💥 BONKED by {by}!\nBack in {string.format("%.1f", seconds - (os.clock() - t0))}s`
				task.wait(0.1)
			end
			downCard.Visible = false
		end)
	end)
	Net.listen("Toast", function(text)
		toastLabel.Text = tostring(text)
		local mine = text
		task.delay(4, function()
			if toastLabel.Text == mine then
				toastLabel.Text = ""
			end
		end)
	end)
	task.spawn(function()
		while true do
			koLabel.Text = `⚔️ BONK ARENA · {ArenaController.kos()} KOs`
			task.wait(0.5)
		end
	end)
end

return ArenaController

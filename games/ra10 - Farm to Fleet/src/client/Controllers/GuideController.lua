--[[
The guide on screen and in the world (master plan §9: one line, one arrow, one target, always). The card sits under
the level bar with the step's words; in the world a gold arrow bobs over the target and a dotted path runs along the
ground from you to it (it fades once you're there). Net "Guide" moves them; the server decides the step.

  GuideController.state()   the last Net "Guide"
  GuideController.refs      the card, the arrow, the dots (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local GuideController = { Name = "GuideController", Order = 30, DOTS = 24, SPACING = 3.5, HERE = 7 }

local C = Theme.Color
local GOLD = Constants.PALETTE.sunflower
local player = Players.LocalPlayer
local refs = { dots = {} }
GuideController.refs = refs
local state = {}

function GuideController.state()
	return state
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function worldPart(name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	p.Transparency = 1
	p.Parent = refs.folder
	return p
end

local function paintCard()
	refs.card.Visible = state.text ~= nil
	refs.text.Text = state.text or ""
	refs.count.Text = state.percent and `{state.percent}%`
		or ((state.generated or not state.step) and "★" or `{math.min(state.step, state.of)}/{state.of}`)
end

local function step()
	local target = state.target
	local r = root()
	local t = os.clock()
	if typeof(target) ~= "Vector3" or not r then
		refs.arrow.Transparency = 1
		refs.tip.Transparency = 1
		for _, d in refs.dots do
			d.Transparency = 1
		end
		return
	end
	-- the arrow: a gold block and a point under it, bobbing over the target
	local bob = math.sin(t * 3) * 0.6
	refs.arrow.CFrame = CFrame.new(target + Vector3.new(0, 7.5 + bob, 0)) * CFrame.Angles(0, t * 2, 0)
	refs.tip.CFrame = CFrame.new(target + Vector3.new(0, 5.6 + bob, 0)) * CFrame.Angles(0, t * 2, math.rad(45))
	refs.arrow.Transparency = 0.1
	refs.tip.Transparency = 0.1
	-- the path: dots on the ground from here to there, moving toward it
	local from = Vector3.new(r.Position.X, target.Y, r.Position.Z)
	local to = target - from
	local dist = Vector3.new(to.X, 0, to.Z).Magnitude
	local here = dist < GuideController.HERE
	local dir = dist > 0 and Vector3.new(to.X, 0, to.Z).Unit or Vector3.zero
	local slide = (t * 4) % GuideController.SPACING
	for i, d in refs.dots do
		local along = (i - 1) * GuideController.SPACING + slide + 2
		if here or along > dist - 1.5 then
			d.Transparency = 1
		else
			d.CFrame = CFrame.new(from + dir * along + Vector3.new(0, 0.35, 0))
			d.Transparency = 0.25
		end
	end
end

function GuideController:init()
	local gui = Theme.screen("Guide", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(460, 52),
		BackgroundColor3 = C.paper,
		Visible = false,
		Parent = gui,
	})
	refs.card = card
	refs.count = Theme.text({
		Name = "Count",
		Text = "",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(52, 36),
		Font = Theme.Display,
		TextColor3 = Color3.fromRGB(230, 150, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 18,
		Parent = card,
	})
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(66, 6),
		Size = UDim2.new(1, -76, 1, -12),
		Font = Theme.Display,
		fit = 20,
		Parent = card,
	})
	local folder = Instance.new("Folder")
	folder.Name = "GuidePath"
	folder.Parent = workspace
	refs.folder = folder
	refs.arrow = worldPart("GuideArrow", Vector3.new(1.4, 2.4, 1.4))
	refs.tip = worldPart("GuideTip", Vector3.new(1.5, 1.5, 0.5))
	for i = 1, GuideController.DOTS do
		refs.dots[i] = worldPart("GuideDot", Vector3.new(0.9, 0.12, 0.9))
	end
	Net.listen("Guide", function(g)
		if type(g) ~= "table" then
			return
		end
		state = g
		paintCard()
		Theme.pop(card)
	end)
	RunService.Heartbeat:Connect(step)
end

return GuideController

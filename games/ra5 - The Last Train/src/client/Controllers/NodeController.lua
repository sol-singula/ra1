-- The piles at a stop, from your side. Material piles and the blueprint are per player (everyone can take each one
-- once), so a pile you took disappears for you only; fuel cans are the crew's and the server removes them.
--   * "Nodes" { reset } / { taken = { ids } }: hide what you've taken (and its prompt)
--   * the Radio Mast: a tall blue beacon over the blueprint, so it can be seen from anywhere at the stop
--   * the Explorer specialist: a compass line from you to the blueprint until you have it
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local NodeController = { Name = "NodeController", Order = 46 }

local hidden = {} -- [nodeId] = true
local beacon, compass, compassTarget

local function scenery()
	return workspace:FindFirstChild("Scenery")
end

-- Every pile beside the train right now: { [nodeId] = model }
function NodeController.nodes()
	local out = {}
	local s = scenery()
	if not s then
		return out
	end
	for _, m in s:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Node") and m:GetAttribute("NodeId") then
			out[m:GetAttribute("NodeId")] = m
		end
	end
	return out
end

local function setVisible(model, on)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p:GetAttribute("LocalT") == nil then
				p:SetAttribute("LocalT", p.Transparency)
			end
			p.Transparency = on and p:GetAttribute("LocalT") or 1
			p.CanCollide = false
		elseif p:IsA("Light") or p:IsA("ProximityPrompt") then
			p.Enabled = on
		end
	end
end

local function blueprintNode()
	for id, m in NodeController.nodes() do
		if m:GetAttribute("Node") == "blueprint" and not hidden[id] then
			return m
		end
	end
	return nil
end

local function refreshBeacon()
	local e = Store.state.expedition
	local radio = e and e.upgrades and (e.upgrades.lamp or 0) >= 2
	local bp = blueprintNode()
	if radio and bp and bp.PrimaryPart then
		if not beacon then
			beacon = new("Part", {
				Name = "BlueprintBeacon",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.Neon,
				Color = C.blue,
				Transparency = 0.55,
				Size = Vector3.new(0.6, 80, 0.6),
				Parent = workspace,
			})
		end
		beacon.CFrame = CFrame.new(bp.PrimaryPart.Position + Vector3.new(0, 40, 0))
		beacon.Transparency = 0.55
	elseif beacon then
		beacon.Transparency = 1
	end
end

local function refreshCompass()
	local cabin = Store.state.cabin
	local explorer = cabin
		and cabin.built
		and cabin.built.specialist
		and cabin.variants
		and cabin.variants.specialist == "explorer"
	local bp = explorer and blueprintNode()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not bp or not bp.PrimaryPart or not hrp then
		if compass then
			compass.Enabled = false
		end
		return
	end
	if not compass then
		local anchor = new("Part", {
			Name = "CompassTarget",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = workspace,
		})
		compassTarget = new("Attachment", { Name = "Target", Parent = anchor })
		compass = new("Beam", {
			Name = "ExplorerCompass",
			Attachment1 = compassTarget,
			Color = ColorSequence.new(C.blue),
			Width0 = 0.25,
			Width1 = 0.6,
			FaceCamera = true,
			LightEmission = 1,
			Transparency = NumberSequence.new(0.3, 0.6),
			Parent = anchor,
		})
	end
	compassTarget.Parent.CFrame = CFrame.new(bp.PrimaryPart.Position)
	compass.Attachment0 = hrp:FindFirstChild("CompassFrom") or new("Attachment", { Name = "CompassFrom", Parent = hrp })
	compass.Enabled = true
end

function NodeController.apply(msg)
	if type(msg) ~= "table" then
		return
	end
	local prompts = require(script.Parent.PromptController)
	if msg.reset then
		hidden = {}
	end
	for _, id in msg.taken or {} do
		if not msg.shared then
			hidden[id] = true
		end
	end
	local nodes = NodeController.nodes()
	for id, m in nodes do
		if hidden[id] then
			setVisible(m, false)
		end
	end
	local mine = {}
	for id in hidden do
		table.insert(mine, id)
	end
	prompts.markTaken(mine, true)
	refreshBeacon()
end

function NodeController.isHidden(id)
	return hidden[id] == true
end

function NodeController:init()
	Net.listen("Nodes", NodeController.apply)
	Store.Changed:Connect(function(partial)
		if partial.expedition then
			refreshBeacon()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			refreshCompass()
		end
	end)
end

return NodeController

-- Left behind, from your side: the night sky over the signal hut (the "recovery" lighting, on this screen only),
-- a short objective card where the departure board usually is, and a glowing line to the next thing to do: a fuse
-- you haven't found, then the fuse box, then the lever. Fuses you've picked up disappear for you. When the trolley
-- brings you back, the train's lighting returns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local RecoveryController = { Name = "RecoveryController", Order = 47 }

local gui, cardFrame, stepText, countText
local beam, targetAnchor
local active = false

local function hut()
	return workspace:FindFirstChild("Recovery")
end

local function fuses()
	local out = {}
	local h = hut()
	if h then
		for _, d in h:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Fuse") then
				out[d:GetAttribute("Fuse")] = d
			end
		end
	end
	return out
end

local function find(name)
	local h = hut()
	return h and h:FindFirstChild(name, true)
end

-- What to walk to next.
function RecoveryController.target(rec)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not rec or not hrp then
		return nil
	end
	if rec.step == "fuses" then
		local taken = {}
		for _, i in rec.taken or {} do
			taken[i] = true
		end
		local best, bestD
		for i, f in fuses() do
			if not taken[i] then
				local d = (f.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then
					best, bestD = f, d
				end
			end
		end
		return best
	elseif rec.step == "box" then
		return find("FuseBox")
	elseif rec.step == "lever" then
		return find("Lever")
	end
	return nil
end

local function refresh()
	local rec = Store.state.recovery
	local on = type(rec) == "table"
	cardFrame.Visible = on
	if on then
		stepText.Text = rec.text or ""
		if rec.step == "waiting" and rec.pickupAt then
			countText.Text = `🚨 Pickup in {Format.time(math.max(0, rec.pickupAt - workspace:GetServerTimeNow()))}`
		elseif rec.step == "fuses" then
			countText.Text = `🔌 Fuses {rec.found or 0}/{rec.need or 3}`
		else
			countText.Text = rec.step == "box" and "🔌 Fuses 3/3 · to the fuse box"
				or "⚡ Power on · pull the lever"
		end
		-- hide the fuses you've taken
		local taken = {}
		for _, i in rec.taken or {} do
			taken[i] = true
		end
		for i, f in fuses() do
			f.Transparency = taken[i] and 1 or 0
			for _, l in f:GetChildren() do
				if l:IsA("Light") then
					l.Enabled = not taken[i]
				elseif l:IsA("ProximityPrompt") then
					l.Enabled = not taken[i] and rec.step == "fuses"
				end
			end
		end
	end
	if on ~= active then
		active = on
		if on then
			LightingPresets.apply("recovery")
		else
			LightingPresets.apply(workspace:GetAttribute("LightPreset") or "travel")
			for _, f in fuses() do
				f.Transparency = 0
			end
		end
	end
end
RecoveryController.refresh = refresh

local function refreshBeam()
	local rec = Store.state.recovery
	local target = type(rec) == "table" and RecoveryController.target(rec) or nil
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not target or not hrp then
		if beam then
			beam.Enabled = false
		end
		return
	end
	if not beam then
		targetAnchor = new("Part", {
			Name = "RecoveryTarget",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = workspace,
		})
		local a1 = new("Attachment", { Name = "Target", Parent = targetAnchor })
		beam = new("Beam", {
			Name = "RecoveryBeam",
			Attachment1 = a1,
			Color = ColorSequence.new(C.amber),
			Width0 = 0.35,
			Width1 = 0.35,
			FaceCamera = true,
			LightEmission = 1,
			Transparency = NumberSequence.new(0.2),
			Parent = targetAnchor,
		})
	end
	targetAnchor.CFrame = CFrame.new(target.Position)
	beam.Attachment0 = hrp:FindFirstChild("RecoveryFrom")
		or new("Attachment", { Name = "RecoveryFrom", Position = Vector3.new(0, -1.5, 0), Parent = hrp })
	beam.Enabled = true
end

function RecoveryController:init()
	gui = Theme.screen("Recovery", 12, player:WaitForChild("PlayerGui"))
	cardFrame = Theme.slab({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	cardFrame.UIStroke.Color = C.bad
	Theme.padding(12, 8).Parent = cardFrame
	Theme.list("y", 4, Enum.HorizontalAlignment.Center).Parent = cardFrame
	Theme.title({
		Name = "Title",
		Text = "Left behind",
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = C.bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = cardFrame,
	})
	stepText = Theme.text({
		Name = "Step",
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = cardFrame,
	})
	countText = Theme.title({
		Name = "Count",
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = C.amber,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		Parent = cardFrame,
	})
	Theme.text({
		Name = "Safe",
		Text = "Your cabin and storage are safe. Only the bag was lost.",
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		Parent = cardFrame,
	})
	Store.Changed:Connect(function(partial)
		if partial.recovery ~= nil then
			refresh()
		end
	end)
	-- the server changes the lighting at every phase: keep the night while you're out here
	workspace:GetAttributeChangedSignal("LightPreset"):Connect(function()
		if active then
			task.defer(LightingPresets.apply, "recovery")
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			if active then
				refresh()
			end
			refreshBeam()
		end
	end)
	refresh()
end

return RecoveryController

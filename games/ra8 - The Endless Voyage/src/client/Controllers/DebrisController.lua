--[[
Debris on this client (master plan §7: collecting is the heartbeat; and the frame rate). The server only decides
where a piece is: it spawns the model with a start position, a time and a velocity on the server's clock, and says
who is pulling it in (attributes on the model, OceanService). Every client moves the model itself each frame from
those numbers, so the drift never crosses the network, and what you aim at is where the server says it is.

  T0, Pos0, Vel, Bob, Yaw                 drifting: pos = Pos0 + Vel * (now - T0), bobbing on the waves
  Pull, PullFrom, PullT0, PullSpeed       hooked: heading for that player's feet at that speed (the server collects
                                          it when it arrives and the model goes)
Pieces more than FAR studs from the camera are placed every few frames, not every frame.
The pieces carry no badges (the models are big and bright enough); only the guide's crate wears a beacon: a tall
pillar of light and a "CAST HERE!" sign, so there's no wondering which crate it means.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Store = require(script.Parent.Parent.Store)

local DebrisController = { Name = "DebrisController", Order = 35 }

local FAR = 220
local BEACON_GOLD = Color3.fromRGB(255, 214, 90)
local pulls = {} -- [model] = { pos, at } the integrated pull so far
local frame = 0
local myPlot -- (this player's plot: only its guide crate gets a beacon)

local function place(m, t, dt, camPos, nth)
	local t0 = m:GetAttribute("T0")
	local pos0 = m:GetAttribute("Pos0")
	if type(t0) ~= "number" or typeof(pos0) ~= "Vector3" then
		return
	end
	local vel = m:GetAttribute("Vel")
	local pos = pos0 + (typeof(vel) == "Vector3" and vel or Vector3.zero) * (t - t0)
	local puller = m:GetAttribute("Pull")
	if puller then
		local from, pt0, speed = m:GetAttribute("PullFrom"), m:GetAttribute("PullT0"), m:GetAttribute("PullSpeed")
		local p = Players:GetPlayerByUserId(puller)
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if typeof(from) == "Vector3" and type(pt0) == "number" and root then
			local s = pulls[m]
			if not s then
				-- catch up with a pull that started before this piece streamed in
				local to = root.Position - from
				local flat = Vector3.new(to.X, 0, to.Z)
				local dist = flat.Magnitude
				local gone = math.min(dist, (speed or 14) * math.max(0, t - pt0))
				s = { pos = from + (dist > 0.01 and flat.Unit * gone or Vector3.zero) }
				pulls[m] = s
			else
				local to = root.Position - s.pos
				local flat = Vector3.new(to.X, 0, to.Z)
				local dist = flat.Magnitude
				if dist > 0.01 then
					s.pos += flat.Unit * math.min(dist, (speed or 14) * dt * nth)
				end
			end
			pos = s.pos
		end
	elseif pulls[m] then
		pulls[m] = nil
	end
	local bob = m:GetAttribute("Bob") or 0
	local yaw = m:GetAttribute("Yaw") or 0
	local far = (pos - camPos).Magnitude > FAR
	local y = Constants.WATER_LEVEL + 0.3 + (far and 0 or math.sin(t * 1.6 + bob) * 0.12)
	local cf = CFrame.new(pos.X, y, pos.Z)
	if not far then
		cf = cf * CFrame.Angles(math.sin(t + bob) * 0.04, yaw, math.cos(t * 0.8 + bob) * 0.05)
	else
		cf = cf * CFrame.Angles(0, yaw, 0)
	end
	m:PivotTo(cf)
end

-- The guide's crate: a pillar of light and a sign over it.
local function beacon(m)
	if m:FindFirstChild("GuideBeacon") then
		return
	end
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end
	local at = m:GetPivot()
	local pillar = Instance.new("Part")
	pillar.Name = "GuideBeacon"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(40, 2.4, 2.4)
	pillar.CFrame = at * CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Material = Enum.Material.Neon
	pillar.Color = BEACON_GOLD
	pillar.Transparency = 0.45
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Parent = m
	local ring = Instance.new("Part")
	ring.Name = "GuideBeaconRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 7, 7)
	ring.CFrame = at * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = BEACON_GOLD
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = m
	local sign = Instance.new("BillboardGui")
	sign.Name = "GuideSign"
	sign.Adornee = anchor
	sign.Size = UDim2.fromOffset(190, 54)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 300
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(220, 70, 50)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.Text = "📦 CAST HERE!"
	label.TextScaled = true
	label.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	sign.Parent = m
end

local function step(dt)
	local folder = workspace:FindFirstChild("Debris")
	if not folder then
		return
	end
	frame += 1
	myPlot = (Store.get("me") or {}).plot
	local t = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
	for i, m in folder:GetChildren() do
		if m:GetAttribute("DebrisId") then
			-- far pieces every 6th frame (staggered), near ones every frame
			local pivot = m:GetPivot().Position
			local dist = (pivot - camPos).Magnitude
			local far = dist > FAR
			if m:GetAttribute("Guide") then
				-- (only your own plot's guide crate gets the beacon and the sign: everyone else's stays a crate)
				local mine = m:GetAttribute("Plot") == myPlot
				if mine and (frame + i) % 10 == 0 then
					beacon(m)
				end
				local pillar = m:FindFirstChild("GuideBeacon")
				local ring = m:FindFirstChild("GuideBeaconRing")
				local sign = m:FindFirstChild("GuideSign")
				if pillar then
					pillar.Transparency = (m:GetAttribute("Pull") or not mine) and 1 or 0.35 + 0.25 * math.sin(t * 5)
				end
				if ring then
					ring.Transparency = mine and 0.35 or 1
				end
				if sign then
					sign.Enabled = mine and not m:GetAttribute("Pull")
				end
			end
			if not far then
				place(m, t, dt, camPos, 1)
			elseif (frame + i) % 6 == 0 then
				place(m, t, dt, camPos, 6)
			end
		end
	end
	for m in pulls do
		if not m.Parent then
			pulls[m] = nil
		end
	end
end

function DebrisController:init()
	RunService.RenderStepped:Connect(step)
end

-- (tests)
DebrisController.step = step

return DebrisController

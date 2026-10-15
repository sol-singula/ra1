--[[
Debris on this client (master plan §7: collecting is the heartbeat; and the frame rate). The server only decides
where a piece is: it spawns the model with a start position, a time and a velocity on the server's clock, and says
who is pulling it in (attributes on the model, OceanService). Every client moves the model itself each frame from
those numbers, so the drift never crosses the network, and what you aim at is where the server says it is.

  T0, Pos0, Vel, Bob, Yaw                 drifting: pos = Pos0 + Vel * (now - T0), bobbing on the waves
  Pull, PullFrom, PullT0, PullSpeed       hooked: heading for that player's feet at that speed (the server collects
                                          it when it arrives and the model goes)
Pieces more than FAR studs from the camera are placed every few frames, not every frame.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local DebrisController = { Name = "DebrisController", Order = 35 }

local FAR = 220
local pulls = {} -- [model] = { pos, at } the integrated pull so far
local frame = 0

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

local function step(dt)
	local folder = workspace:FindFirstChild("Debris")
	if not folder then
		return
	end
	frame += 1
	local t = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
	for i, m in folder:GetChildren() do
		if m:GetAttribute("DebrisId") then
			-- far pieces every 6th frame (staggered), near ones every frame
			local pivot = m:GetPivot().Position
			local far = (pivot - camPos).Magnitude > FAR
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

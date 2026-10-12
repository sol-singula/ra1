-- Brings the secret disco (Disco.lua) to life: dance floor tiles change colour to the beat, the mirror ball spins
-- (its spotlights sweep the room), the lasers sway and the dragons dance. Only runs while you're near the room,
-- and holds still with Reduced Motion on.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local DiscoController = { Name = "DiscoController", Order = 60 }

local COLORS = {
	Color3.fromRGB(255, 60, 140),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(140, 90, 255),
	Color3.fromRGB(80, 255, 140),
	Color3.fromRGB(255, 120, 40),
}
local NEAR = 90 -- studs from the room's centre
local BEAT = 60 / 124 -- seconds per beat

local disco
local tiles, lasers, dancers, ball = {}, {}, {}, nil
local centre

local function collect()
	tiles, lasers, dancers, ball = {}, {}, {}, nil
	for _, d in disco:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("DiscoTile") then
				table.insert(tiles, d)
			elseif d:GetAttribute("DiscoLaser") then
				table.insert(lasers, { part = d, origin = d:GetAttribute("Origin"), base = d.CFrame })
			elseif d:GetAttribute("DiscoBall") then
				ball = d
			end
		end
	end
	for _, m in disco:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("DiscoDancer") then
			table.insert(dancers, { model = m, home = m:GetAttribute("Home"), k = m:GetAttribute("DiscoDancer") })
		end
	end
	centre = ball and ball.Position or nil
end

-- One frame of the party at time t (exposed for tests).
function DiscoController.step(t)
	if not disco or not centre then
		return
	end
	local beat = math.floor(t / BEAT)
	for _, tile in tiles do
		local n = tile:GetAttribute("DiscoTile")
		tile.Color = COLORS[(n * 7 + beat * (n % 3 + 1)) % #COLORS + 1]
	end
	if ball then
		ball.CFrame = CFrame.new(centre) * CFrame.Angles(0, t * 1.2, 0)
	end
	for i, l in lasers do
		local sway = math.sin(t * (0.8 + i * 0.13) + i) * 0.5
		local tilt = math.cos(t * (0.6 + i * 0.07) + i * 2) * 0.25
		local origin = l.origin or l.part.Position
		local dir = l.base.LookVector
		local cf = CFrame.lookAt(origin, origin + dir) * CFrame.Angles(tilt, sway, 0)
		l.part.CFrame = cf * CFrame.new(0, 0, -l.part.Size.Z / 2)
		l.part.Color = COLORS[(i + beat) % #COLORS + 1]
	end
	for _, d in dancers do
		if d.home then
			local phase = t / BEAT * math.pi + d.k
			local hop = math.abs(math.sin(phase)) * 1.2
			local spin = d.k == 1 and math.sin(phase * 0.5) * 0.4 or t * 1.5
			d.model:PivotTo(d.home * CFrame.new(0, hop, 0) * CFrame.Angles(0, spin, math.sin(phase) * 0.15))
		end
	end
end

function DiscoController:init()
	local function find()
		local map = workspace:FindFirstChild("Map")
		local found = map and map:FindFirstChild("Disco", true)
		if found and found ~= disco then
			disco = found
			collect()
		end
		return disco
	end
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if not disco then
			if acc < 2 then
				return
			end
			acc = 0
			if not find() then
				return
			end
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or not centre or (hrp.Position - centre).Magnitude > NEAR or Theme.reducedMotion() then
			return
		end
		DiscoController.step(os.clock())
	end)
end

return DiscoController

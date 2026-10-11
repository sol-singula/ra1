-- Combat input and effects: Attack (click / R2), Calm Down! (Q / L1), mutation ability (G / R1),
-- the on-screen ability buttons for touch, and the arcs of food thrown by angry customers.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local HudController = require(script.Parent.HudController)

local CombatController = { Name = "CombatController", Order = 50 }

local function attack()
	Net.send("Attack")
end

local function calm()
	Net.send("Ability", "ABL_006")
end

local function mutationAbility()
	local id = Store.get("ability")
	if id then
		Net.send("Ability", id)
	end
end

local function bind(name, fn, ...)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

-- Thrown food: a scripted parabola (canon C3: no physics), drawn locally on every client.
local function projectile(from, to, flight, color)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1, 1, 1)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Parent = workspace.CurrentCamera
	local start = os.clock()
	local height = math.max(4, (to - from).Magnitude * 0.25)
	task.spawn(function()
		while true do
			local t = math.min((os.clock() - start) / flight, 1)
			local pos = from:Lerp(to, t) + Vector3.new(0, 4 * height * t * (1 - t), 0)
			p.CFrame = CFrame.new(pos) * CFrame.Angles(t * 8, t * 5, 0)
			if t >= 1 then
				break
			end
			task.wait()
		end
		-- splat
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, 3, 3)
		p.CFrame = CFrame.new(to - Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(p, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		task.wait(1.6)
		p:Destroy()
	end)
end

function CombatController:init()
	bind("MMR_Attack", attack, Enum.KeyCode.ButtonR2)
	-- clicks that land on UI (buttons, prompts, panels) are not attacks
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		end
	end)
	bind("MMR_Calm", calm, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	bind("MMR_Mutation", mutationAbility, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)
	HudController:abilityButton("ABL_001").Activated:Connect(attack)
	HudController:abilityButton("ABL_006").Activated:Connect(calm)
	HudController:abilityButton("MUTATION").Activated:Connect(mutationAbility)
	Net.listen("Projectile", projectile)
end

return CombatController

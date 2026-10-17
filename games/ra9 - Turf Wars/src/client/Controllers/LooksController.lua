--[[
The cosmetics others wear, drawn on this client (Data/Cosmetics looks):

  * kill effects: where someone falls, the killer's effect plays (Net "Kill" carries it): FX/KillEffects draws them
    (KillFxController starts them), LooksController.play is the way in for the menus and tests
  * your own name tag, crown, halo and held bow (StatusService puts them on your character for everyone else) are hidden
    from you: in first person they'd sit in your view

  LooksController.play(effectKey, pos, team)   (tests call it too)
  LooksController.count()                       pieces on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local KillEffects = require(script.Parent.Parent.FX.KillEffects)
require(ReplicatedStorage.Shared.Data.Season) -- (season effects resolve)

local LooksController = { Name = "LooksController", Order = 46 }

local player = Players.LocalPlayer
local folder
local bits = {} -- { part, vel, born, life, grow, spin }

-- (the kill effects themselves live in FX/KillEffects: each its own animation; KillFxController plays them on a kill)
function LooksController.play(effectKey, pos, team, opts)
	return KillEffects.play(effectKey, pos, team, opts) ~= nil
end

function LooksController.count()
	return #bits + KillEffects.pieces()
end

local function step(dt)
	local t = os.clock()
	for i = #bits, 1, -1 do
		local b = bits[i]
		local age = t - b.born
		if age >= b.life then
			b.part:Destroy()
			table.remove(bits, i)
		else
			b.vel = b.vel * (1 - math.min(1, dt * 2.2))
			b.part.CFrame = b.part.CFrame + b.vel * dt
			local k = age / b.life
			b.part.Transparency = math.clamp(k * k, 0, 1)
			if b.grow then
				b.part.Size = b.size * math.max(0.05, 1 + b.grow * k)
			end
		end
	end
	-- your own tag, crown and halo: out of your view
	local c = player.Character
	if c then
		local tag = c:FindFirstChild("StatusTag")
		if tag and tag.Enabled ~= false then
			tag.Enabled = false
		end
		for _, d in c:GetChildren() do
			if (d.Name == "MvpCrown" or d.Name == "VipHalo") and d.LocalTransparencyModifier ~= 1 then
				d.LocalTransparencyModifier = 1
			elseif d.Name == "HeldBow" then
				for _, q in d:GetChildren() do
					if q:IsA("BasePart") and q.LocalTransparencyModifier ~= 1 then
						q.LocalTransparencyModifier = 1 -- (you see the viewmodel instead)
					end
				end
			end
		end
	end
end

function LooksController:init()
	folder = Instance.new("Folder")
	folder.Name = "Looks"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(step)
end

return LooksController

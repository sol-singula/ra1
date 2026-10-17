--[[
Knockouts as the store art shows them (drawn on each client): whoever falls shatters. Their body is hidden on this
client and bursts into white and team-coloured shards that fly on along the arrow's direction (a blade's slash, a
blast's push), with a neon flash, a ring shockwave, sparks and a short glow (Effects.shatter: pooled and capped, the
light version on a phone).

The killer gets a crisp pop on top: the hit marker grows into an X (HudController), a quick colour flash with red and
cyan fringes at the edges of the screen, and a small kick of the field of view.

  KillFxController.onKill(k)    a Kill message: the shatter and the killer's kill effect (FX/KillEffects)
  KillFxController.shatter(k)   the shatter for a Kill message (tests call it too); returns the pieces made
  KillFxController.pop()        the killer's screen pop
  KillFxController.body(k)      the fallen body's model, if it's still there
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Effects = require(script.Parent.Parent.FX.Effects)
local KillEffects = require(script.Parent.Parent.FX.KillEffects)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)

local KillFxController = { Name = "KillFxController", Order = 48 }

local player = Players.LocalPlayer
local refs = {}
KillFxController.refs = refs
local popAt -- os.clock() of the last pop
local POP = 0.38

function KillFxController.body(k)
	local who = Players:GetPlayerByUserId(k.victim or 0)
	local c = who and who.Character
	if c then
		return c
	end
	-- a bot: its stand-in body carries its id
	local bots = workspace:FindFirstChild("Bots")
	for _, m in bots and bots:GetChildren() or {} do
		if m:GetAttribute("BotId") == k.victim then
			return m
		end
	end
	return nil
end

-- which way the shards fly: on along the arrow, away from the killer, or up
local function direction(k)
	local cam = type(k.cam) == "table" and k.cam or nil
	if cam and typeof(cam.velocity) == "Vector3" and cam.velocity.Magnitude > 0.01 then
		return cam.velocity.Unit
	end
	if typeof(k.killerPos) == "Vector3" and typeof(k.pos) == "Vector3" then
		local d = k.pos - k.killerPos
		d = Vector3.new(d.X, math.max(d.Y, 0) + d.Magnitude * 0.25, d.Z)
		if d.Magnitude > 0.01 then
			return d.Unit
		end
	end
	return Vector3.yAxis
end

function KillFxController.shatter(k)
	if type(k) ~= "table" or typeof(k.pos) ~= "Vector3" then
		return 0
	end
	local body = KillFxController.body(k)
	local parts = {}
	if body then
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				d.LocalTransparencyModifier = 1 -- (gone, here: it's the shards now)
			elseif d:IsA("Decal") then
				d.Transparency = 1
			end
		end
	end
	local root = body and body:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or (k.pos + Vector3.new(0, 0.5, 0))
	local power = k.kind == "blast" and 1.5 or (k.kind == "melee" and 0.8 or 1)
	return Effects.shatter({ pos = pos, dir = direction(k), team = k.victimTeam, parts = parts, power = power })
end

-- A Kill message, here: the shatter, and the killer's kill effect (FX/KillEffects) where they fell. An effect that
-- carries the body off (balloons, a web, a black hole...) takes a still copy of it instead of shattering it. Your own
-- death's effect is your kill cam's to play (slowed, on you), so it's left to it when it takes it.
function KillFxController.onKill(k)
	if type(k) ~= "table" or typeof(k.pos) ~= "Vector3" then
		return nil
	end
	local it = k.effect and Cosmetics.get(k.effect)
	local look = it and it.kind == "effect" and it.look or nil
	local standin
	if look and KillEffects.usesBody(look.shape) then
		local body = KillFxController.body(k)
		local root = body and body:FindFirstChild("HumanoidRootPart")
		if root then
			standin = Effects.lookalike(body, root.CFrame, k.victimTeam)
		end
		for _, d in body and body:GetDescendants() or {} do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") then
				d.Transparency = 1
			end
		end
		if not standin then
			KillFxController.shatter(k)
		end
	else
		KillFxController.shatter(k)
	end
	if not look then
		return nil
	end
	local function go()
		if KillEffects.claimed(k) then
			if standin then
				standin:Destroy()
			end
			return
		end
		KillEffects.play(k.effect, k.pos, k.killerTeam, {
			body = standin,
			victimTeam = k.victimTeam,
			dir = direction(k),
		})
	end
	-- (after the kill cam has had its say this frame)
	task.defer(go)
	return true
end

local function build()
	local gui = Theme.screen("KillPop", 12, player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	refs.gui = gui
	local function fringe(name, color, x)
		return Theme.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(x, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0.16, 0, 1, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = gui,
		}, {
			Theme.new("UIGradient", {
				Rotation = x == 0 and 0 or 180,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	refs.left = fringe("Red", Color3.fromRGB(255, 40, 70), 0)
	refs.right = fringe("Cyan", Color3.fromRGB(40, 220, 255), 1)
	refs.flash = Theme.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
end

function KillFxController.pop()
	popAt = os.clock()
	pcall(function()
		local cc = Lighting:FindFirstChild("TW_KillPop") or Instance.new("ColorCorrectionEffect")
		cc.Name = "TW_KillPop"
		cc.Parent = Lighting
	end)
end

local function step()
	local k = popAt and (os.clock() - popAt) / POP or 1
	if k >= 1 then
		if popAt then
			popAt = nil
			CameraController.setFov("killpop", nil)
			local cc = Lighting:FindFirstChild("TW_KillPop")
			if cc then
				cc:Destroy()
			end
			if refs.left then
				refs.left.BackgroundTransparency, refs.right.BackgroundTransparency = 1, 1
				refs.flash.BackgroundTransparency = 1
			end
		end
		return
	end
	local e = (1 - k) ^ 2
	-- the field of view kicks out and settles, the colour punches up and settles, the fringes flash and go
	CameraController.setFov("killpop", 7 * e)
	local cc = Lighting:FindFirstChild("TW_KillPop")
	if cc then
		cc.Contrast = 0.18 * e
		cc.Saturation = 0.25 * e
		cc.Brightness = 0.06 * e
	end
	if refs.left then
		refs.left.BackgroundTransparency = 1 - 0.55 * e
		refs.right.BackgroundTransparency = 1 - 0.55 * e
		refs.left.Position = UDim2.new(0, -12 * k, 0, 0)
		refs.right.Position = UDim2.new(1, 12 * k, 0, 0)
		refs.flash.BackgroundTransparency = 1 - 0.18 * math.max(0, 1 - k * 4)
	end
end

function KillFxController:init()
	build()
	Net.listen("Kill", function(k)
		if type(k) == "table" and k.pos then
			KillFxController.onKill(k)
		end
	end)
	Net.listen("Hit", function(h)
		if type(h) == "table" and h.kill then
			KillFxController.pop()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return KillFxController

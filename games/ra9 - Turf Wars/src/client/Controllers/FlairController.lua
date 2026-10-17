--[[
The cosmetics others wear, alive on this client (FX/Flair):

  * the bow in everyone else's hand (CombatService builds it plain: "HeldBow"): painted with the skin they wear (their
    LookSkin attribute), then animated: a rainbow or candy stripes sliding along the limbs, lava pulsing, galaxy
    sparkles, frost, lightning crackling, golden dragon wings flapping, embers, snow or sparks coming off it
  * the blade in everyone else's hand in the CHARGE (CombatService builds it in the sword skin they wear, "HeldBow"
    with Weapon "blade"; Shared/SwordSkins): a rainbow or lava moving, a neon edge throbbing, arcs crackling down a
    Lightning Fang, embers, snow, sparks or dark smoke off it, the Doge sticker on the guard
  * the banner emblems on every flag (BuildService: a SurfaceGui "Emblem"): fire off a Flame, a Rainbow's hues, a
    Lightning flicker, a Doge pulse, a Chicken bounce, Skulls spinning, a Galaxy or Crown sparkling
  * the loose bits everything drops (feathers, bubbles, blocks, hearts...): Flair.step every frame

Far-off bows and banners are updated less often; your own held bow is hidden (you see the view model, which
WeaponController decorates itself).

  FlairController.bows()      bows decorated now (tests)
  FlairController.swords()    blades brought alive now (tests)
  FlairController.banners()   banners animated now (tests)
  FlairController.scan()      look for new bows and banners at once (tests; it runs every half second anyway)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local SwordSkins = require(ReplicatedStorage.Shared.SwordSkins)
local Flair = require(script.Parent.Parent.FX.Flair)

local FlairController = { Name = "FlairController", Order = 47 }

local player = Players.LocalPlayer
local bows = {} -- [HeldBow model] = { handle, skin }
local banners = {} -- [TextLabel] = handle
local FAR = 140 -- studs: past this, a bow or banner updates a few times a second, not every frame

-- the banner anim for an emblem character, from every banner the game has
local animOf
local function emblemAnim(text)
	if not animOf then
		animOf = {}
		for _, it in Cosmetics.list do
			if it.kind == "banner" and it.look and it.look.emblem and it.look.anim then
				animOf[it.look.emblem] = it.look.anim
			end
		end
	end
	return animOf[text]
end

local function needsFlair(look)
	return look
		and (
			look.anim
			or look.particles
			or look.wings
			or Flair.moving(look.grip)
			or Flair.moving(look.limbs)
			or look.material
		)
end

local function scanBows()
	for _, p in Players:GetPlayers() do
		local c = p ~= player and p.Character
		local model = c and c:FindFirstChild("HeldBow")
		if model then
			local weapon = model:GetAttribute("Weapon")
			local skinKey = weapon == "blade" and p:GetAttribute("LookSword") or p:GetAttribute("LookSkin")
			local have = bows[model]
			if have and have.skin ~= skinKey then
				have.handle:destroy()
				bows[model] = nil
				have = nil
			end
			if not have and weapon == "blade" then
				-- (their blade: the server built it in their skin; its moving parts are this client's)
				local it = Cosmetics.get(skinKey)
				local look = it and it.kind == "sword" and it.look or nil
				if look and (look.anim or look.particles or look.sticker) and model:FindFirstChild("Edge") then
					local handle =
						Flair.sword(SwordSkins.adopt(model, look, p:GetAttribute("Team")), look, p:GetAttribute("Team"))
					bows[model] = { handle = handle, skin = skinKey, owner = p, sword = true }
				else
					bows[model] = { handle = { update = function() end, destroy = function() end }, skin = skinKey }
				end
			elseif not have and (weapon == nil or weapon == "bow" or weapon == "crossbow" or weapon == "heavy") then
				local it = Cosmetics.get(skinKey)
				local look = it and it.kind == "skin" and it.look or nil
				local grip = model:FindFirstChild("Grip")
				if needsFlair(look) and grip then
					local handle = Flair.bow({
						grip = grip,
						limbs = { model:FindFirstChild("Upper"), model:FindFirstChild("Lower") },
						tips = {},
						holder = model,
						scale = 1,
					}, look, p:GetAttribute("Team"), { static = true })
					bows[model] = { handle = handle, skin = skinKey, owner = p }
				else
					bows[model] = { handle = { update = function() end, destroy = function() end }, skin = skinKey }
				end
			end
		end
	end
	for model, b in bows do
		if not model.Parent then
			b.handle:destroy()
			bows[model] = nil
		end
	end
end

local function scanBanners()
	for label, h in banners do
		if not label.Parent then
			h:destroy()
			banners[label] = nil
		end
	end
	local folder = workspace:FindFirstChild("Structures")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == "Emblem" then
			local label = d:FindFirstChildOfClass("TextLabel")
			if label and not banners[label] then
				local anim = emblemAnim(label.Text)
				if anim then
					-- (one flag, two faces: fire or sparkles come off the flag once)
					local part = d.Parent
					local first = true
					for other in banners do
						if other.Parent and other.Parent.Parent == part then
							first = false
						end
					end
					banners[label] = Flair.banner(label, first and part or nil, anim)
				else
					banners[label] = { update = function() end, destroy = function() end }
				end
			end
		end
	end
end

function FlairController.scan()
	pcall(scanBows)
	pcall(scanBanners)
end

function FlairController.bows()
	local n = 0
	for _, b in bows do
		if b.owner and not b.sword then
			n += 1
		end
	end
	return n
end

function FlairController.swords()
	local n = 0
	for _, b in bows do
		if b.owner and b.sword then
			n += 1
		end
	end
	return n
end

function FlairController.banners()
	local n = 0
	for _, h in banners do
		if h.made then
			n += 1
		end
	end
	return n
end

local frame = 0
local function step(dt)
	frame += 1
	Flair.step(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	for model, b in bows do
		local grip = model:FindFirstChild("Grip")
		local far = eye and grip and (grip.Position - eye).Magnitude > FAR
		if not far or frame % 6 == 0 then
			b.handle:update(t)
		end
	end
	for label, h in banners do
		local part = label.Parent and label.Parent.Parent
		local far = eye and part and part:IsA("BasePart") and (part.Position - eye).Magnitude > FAR
		if not far or frame % 6 == 0 then
			h:update(t)
		end
	end
end

function FlairController:init()
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			FlairController.scan()
			task.wait(0.5)
		end
	end)
end

return FlairController

--[[
Cosmetics: equipping (Cosmetic:equip {slot, key?}) and drawing them for everyone (§9.3).

A key may be equipped when it is owned (Purchase.owns: bought, gifted, from the bundle) or earned (also in
cosmetics.owned), a VIP perk for a VIP owner, or the subscriber can for a subscriber. Its slot must match its
prefix: theme_* theme, trail_* trail, tag_* and title_* tag, can_* can. No key unequips the slot.
deco_lantern is plot decor: it stands by the sign while owned. border_vip draws itself on a VIP's tag.

Drawing (all replicated, server-made):
  theme   the plot's Ground and Bed recoloured, Plot attribute Theme
  trail   Attachments TrailA / TrailB on the HumanoidRootPart with a Trail "CosmeticTrail"
  tag     a BillboardGui "CosmeticTag" over the head
  can     character attribute CanSkin, and the Handle colour of a "WateringCan" tool when there is one

VIP pieces are satin brass (BRASS, Config.Brass), never gold.

  Cosmetics.slotOf(key) -> slot?
  Cosmetics.canEquip(player, profile, key) -> true | false, code
  Cosmetics.render(player)
  Cosmetics.BRASS / Cosmetics.LOOK
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.Parent.Services.DataService)
local NetService = require(script.Parent.Parent.Services.NetService)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local PolicyGate = require(script.Parent.Parent.Services.PolicyGate)
local Purchase = require(script.Parent)

local Cosmetics = {}

Cosmetics.BRASS = Color3.fromHex(Config.Brass.hex) -- satin VIP brass (M6), never Golden

-- [key] = { name, color } for drawing; names for the earned and perk keys the Catalog doesn't sell
Cosmetics.LOOK = {
	tag_sprout = { "Sprout Buddy", Color3.fromRGB(110, 190, 90) },
	tag_star = { "Star Farmer", Color3.fromRGB(120, 150, 230) },
	tag_collector = { "Collector", Color3.fromRGB(150, 120, 200) },
	tag_weekly_top100 = { "Top 100", Color3.fromRGB(90, 160, 200) },
	tag_vip = { "VIP Gardener", Cosmetics.BRASS },
	title_master = { "Master Gardener", Color3.fromRGB(200, 110, 90) },
	trail_leaf = { "Leaf Swirl", Color3.fromRGB(100, 180, 80) },
	trail_firefly = { "Firefly Trail", Color3.fromRGB(230, 240, 150) },
	trail_petals = { "Petal Trail", Color3.fromRGB(240, 170, 200) },
	trail_vip_sparkle = { "VIP Sparkle", Cosmetics.BRASS },
	can_pumpkin = { "Pumpkin Can", Color3.fromRGB(230, 120, 40) },
	can_crystal = { "Crystal Can", Color3.fromRGB(170, 220, 240) },
	can_brass = { "Brass Can", Cosmetics.BRASS },
	theme_cherry = { "Cherry Blossom", Color3.fromRGB(240, 190, 210) },
	theme_candy = { "Candy Land", Color3.fromRGB(250, 170, 220) },
	theme_starry = { "Starry Night", Color3.fromRGB(40, 50, 100) },
}

local PREFIX = { theme = "theme", trail = "trail", tag = "tag", title = "tag", can = "can" }

function Cosmetics.slotOf(key)
	local prefix = key:match("^(%a+)_")
	return prefix and PREFIX[prefix]
end

local function isVipPerk(key)
	return table.find(Config.Catalog.vipPerks, key) ~= nil
end

function Cosmetics.canEquip(player, profile, key)
	if profile.cosmetics.owned[key] or Purchase.owns(player, key) then
		return true
	end
	if isVipPerk(key) and Purchase.owns(player, "vip") then
		return true
	end
	if key == Config.Catalog.subscriberPerk and PolicyGate.hasSubscription(player) then
		return true
	end
	return false, "not_owned"
end

local function clear(parent, name)
	local old = parent and parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local function drawTag(player, character, key)
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	clear(head, "CosmeticTag")
	if not head or not key then
		return
	end
	local look = Cosmetics.LOOK[key] or { key, Color3.new(1, 1, 1) }
	local gui = Instance.new("BillboardGui")
	gui.Name = "CosmeticTag"
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(40, 34, 28)
	label.TextColor3 = look[2]
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = look[1]
	label.Parent = gui
	if Purchase.owns(player, "vip") then
		local border = Instance.new("UIStroke")
		border.Name = "border_vip"
		border.Color = Cosmetics.BRASS
		border.Thickness = 2
		border.Parent = label
	end
	gui.Parent = head
end

local function drawTrail(character, key)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in { "CosmeticTrail", "TrailA", "TrailB" } do
		clear(root, name)
	end
	if not key then
		return
	end
	local color = (Cosmetics.LOOK[key] or { key, Color3.new(1, 1, 1) })[2]
	local a = Instance.new("Attachment")
	a.Name = "TrailA"
	a.Position = Vector3.new(0, 0.8, 0)
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Name = "TrailB"
	b.Position = Vector3.new(0, -0.8, 0)
	b.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.6
	trail:SetAttribute("Key", key)
	trail.Parent = root
end

local function drawCan(player, character, key)
	character:SetAttribute("CanSkin", key)
	local look = key and Cosmetics.LOOK[key]
	for _, holder in { character, player:FindFirstChild("Backpack") } do
		local tool = holder and holder:FindFirstChild("WateringCan")
		local handle = tool and tool:FindFirstChild("Handle")
		if handle then
			handle.Color = if look then look[2] else Color3.fromRGB(150, 160, 170)
			if look and look[2] == Cosmetics.BRASS then
				handle.Material = Enum.Material[Config.Brass.material]
				handle.Reflectance = Config.Brass.reflectance
			end
		end
	end
end

local THEME_DEFAULT = { Ground = Color3.fromRGB(96, 168, 72), Bed = Color3.fromRGB(120, 84, 52) }

local function drawPlot(player, profile, key)
	local plot = PlotService.plotOf(player)
	if not plot then
		return
	end
	plot:SetAttribute("Theme", key)
	local color = key and Cosmetics.LOOK[key] and Cosmetics.LOOK[key][2]
	local ground = plot:FindFirstChild("Ground")
	if ground then
		ground.Color = color or THEME_DEFAULT.Ground
	end
	local bed = plot:FindFirstChild("ExtraRow") and plot.ExtraRow:FindFirstChild("Bed")
	if bed then
		bed.Color = if color then color:Lerp(THEME_DEFAULT.Bed, 0.5) else THEME_DEFAULT.Bed
	end
	local lantern = plot:FindFirstChild("Lantern")
	local owns = profile.cosmetics.owned.deco_lantern == true
	if owns and not lantern then
		local sign = plot:FindFirstChild("Sign")
		lantern = Instance.new("Part")
		lantern.Name = "Lantern"
		lantern.Anchored = true
		lantern.CanCollide = false
		lantern.Size = Vector3.new(1, 2, 1)
		lantern.Color = Color3.fromRGB(250, 220, 140)
		lantern.Material = Enum.Material.Neon
		lantern.Position = (if sign then sign.Position else plot:GetPivot().Position) + Vector3.new(3, 0.5, 0)
		lantern.Parent = plot
	elseif not owns and lantern then
		lantern:Destroy()
	end
end

-- equipped keys that are no longer allowed (a pass gift taken back, a lost subscription) don't draw
local function allowed(player, profile, key)
	return key ~= nil and Cosmetics.canEquip(player, profile, key) == true
end

function Cosmetics.render(player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local eq = profile.cosmetics.equipped
	local function pick(slot)
		local key = eq[slot]
		return if allowed(player, profile, key) then key else nil
	end
	drawPlot(player, profile, pick("theme"))
	local character = player.Character
	if character then
		drawTag(player, character, pick("tag"))
		drawTrail(character, pick("trail"))
		drawCan(player, character, pick("can"))
	end
end

function Cosmetics.equip(player, payload, profile)
	local slot, key = payload.slot, payload.key
	if key ~= nil then
		if Cosmetics.slotOf(key) ~= slot then
			return false, "wrong_slot"
		end
		local ok, code = Cosmetics.canEquip(player, profile, key)
		if not ok then
			return false, code
		end
	end
	profile.cosmetics.equipped[slot] = key
	NetService.change(player, { "cosmetics" }, profile.cosmetics)
	Cosmetics.render(player)
	return true
end

return Cosmetics

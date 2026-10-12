-- Rebirth and Nightmare. After all 8 bosses, the REBIRTH pad in the Hub starts you over: planets lock again,
-- you keep every blaster, ore, gem and coin, and you get a star for ever: +25% damage each. Stars show over your
-- head and on the raid board. After one rebirth you can switch NIGHTMARE on: bugs take 10x the shots for you,
-- drop 10x the ore and coins, and the forge rolls a little better while it's on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Scenery = require(script.Parent.Parent.World.Scenery)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RebirthService = {
	Name = "RebirthService",
	Dependencies = { "PlayerDataService", "PlanetService" },
	Reborn = Signal.new("RebirthService.Reborn"), -- (player, stars)
}

local data, planetService
local nightmare = {} -- [player] = true while Nightmare is on (not saved: it's a session choice)

function RebirthService:CanRebirth(player)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	for _, p in Planets.list do
		if (profile.beaten[p.key] or 0) == 0 then
			return false
		end
	end
	return true
end

function RebirthService:Stars(player)
	local profile = data:Get(player)
	return profile and profile.rebirths or 0
end

function RebirthService:IsNightmare(player)
	return nightmare[player] == true
end

-- What a Nightmare player's damage is divided by, and their loot multiplied by.
function RebirthService:NightmareMult(player)
	return nightmare[player] and Constants.NIGHTMARE_MULT or 1
end

function RebirthService:Push(player)
	data:Push(player, {
		rebirths = self:Stars(player),
		canRebirth = self:CanRebirth(player),
		nightmare = self:IsNightmare(player),
	})
end

local function starTag(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local stars = RebirthService:Stars(player)
	local old = head:FindFirstChild("StarTag")
	if stars == 0 then
		if old then
			old:Destroy()
		end
		return
	end
	local gui = old or Instance.new("BillboardGui")
	gui.Name = "StarTag"
	gui.Size = UDim2.fromOffset(120, 26)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local t = gui:FindFirstChild("Text") or Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 215, 60)
	t.TextStrokeTransparency = 0
	t.Text = string.rep("⭐", math.min(Constants.NIGHTMARE_STARS, stars))
		.. (stars > Constants.NIGHTMARE_STARS and ` x{stars}` or "")
	t.Parent = gui
	gui.Parent = head
end

function RebirthService:Rebirth(player)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	if not self:CanRebirth(player) then
		Net.fire(player, "Toast", "Beat all 8 planet bosses first!", "bad")
		return false
	end
	profile.rebirths = (profile.rebirths or 0) + 1
	profile.beaten = {}
	planetService:Travel(player, "HUB")
	planetService:PushPlanet(player)
	starTag(player)
	self:Push(player)
	Net.fire(
		player,
		"Alert",
		`⭐ REBIRTH {profile.rebirths}! +{math.floor(Constants.REBIRTH_DAMAGE * 100)}% damage for ever!`,
		Color3.fromRGB(255, 215, 60)
	)
	Net.fire(player, "Sfx", "win")
	Net.fireAll(
		"Announce",
		`⭐ {player.DisplayName} was REBORN! Star {profile.rebirths}`,
		Color3.fromRGB(255, 215, 60)
	)
	self.Reborn:Fire(player, profile.rebirths)
	return true
end

function RebirthService:ToggleNightmare(player)
	if self:Stars(player) == 0 then
		Net.fire(player, "Toast", "Rebirth once to unlock NIGHTMARE!", "bad")
		return
	end
	nightmare[player] = not nightmare[player] or nil
	self:Push(player)
	Net.fire(
		player,
		"Alert",
		nightmare[player] and `🌑 NIGHTMARE ON: {Constants.NIGHTMARE_MULT}x harder, {Constants.NIGHTMARE_MULT}x loot!`
			or "☀️ Nightmare off",
		nightmare[player] and Color3.fromRGB(190, 120, 255) or Color3.fromRGB(255, 240, 180)
	)
end

function RebirthService:Init(registry)
	data = registry.PlayerDataService
	planetService = registry.PlanetService
	Net.on("Rebirth", function(player)
		self:Rebirth(player)
	end)
	Net.on("Nightmare", function(player)
		self:ToggleNightmare(player)
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- the REBIRTH pad in the Hub: a gold pad behind the forge with a prompt
	local hub = WorldBuilder.layout.hub.model
	local center = Vector3.new(0, 0, -16)
	local padPart =
		Scenery.ring(hub, "RebirthPad", center + Vector3.new(0, 0.25, 0), 9, Color3.fromRGB(255, 215, 60), {})
	Scenery.disc(hub, "RebirthPadBase", center + Vector3.new(0, 0.1, 0), 10.5, 0.2, Color3.fromRGB(30, 30, 44))
	local gui = Scenery.sign(padPart, 10, 3.5, Vector3.new(0, 4.5, 0), {
		{ text = "⭐ REBIRTH", h = 0.55, y = 0, font = Enum.Font.LuckiestGuy, color = Color3.fromRGB(255, 215, 60) },
		{ text = "Beat all 8 bosses, then start over with a star", h = 0.45, y = 0.55 },
	}, 90)
	gui.Size = UDim2.fromOffset(170, 52)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt_rebirth"
	prompt.ActionText = "Rebirth!"
	prompt.ObjectText = "⭐ REBIRTH"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = padPart
	prompt.Triggered:Connect(function(player)
		self:Rebirth(player)
	end)
end

function RebirthService:OnPlayerReady(player)
	local function spawned()
		task.defer(function()
			if player.Parent then
				starTag(player)
			end
		end)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		spawned()
	end
end

function RebirthService:OnPlayerLeaving(player)
	nightmare[player] = nil
end

return RebirthService

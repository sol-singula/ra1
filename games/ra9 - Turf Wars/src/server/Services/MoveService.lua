--[[
What each player says they're doing with their legs (master plan §6): sprinting, sliding, crouched. The client owns
its character and moves it; the server keeps this so the anti-cheat knows how fast someone may go, and so a crouch
shows to everyone (the server lowers their HipHeight, which replicates; their client already did it for itself).

  MoveService:State(player)   { sprint, crouch, slideAt }
  MoveService:Sliding(player) true within a slide's time
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local MoveService = { Name = "MoveService", Dependencies = {} }

local states = {} -- [player] = { sprint, crouch, slideAt, baseHip }

function MoveService:State(player)
	local s = states[player]
	if not s then
		s = { sprint = false, crouch = false, slideAt = -math.huge }
		states[player] = s
	end
	return s
end

function MoveService:Sliding(player)
	return os.clock() - self:State(player).slideAt < Constants.SLIDE_SECONDS + 0.25
end

local function hipOf(player, s)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if not s.baseHip then
		-- (standing height: normally taken when the character spawned)
		s.baseHip = hum.HipHeight
	end
	hum.HipHeight = s.crouch and math.max(0.2, s.baseHip - Constants.CROUCH_DROP) or s.baseHip
end

function MoveService:Init()
	Net.on("Sprint", function(player, on)
		self:State(player).sprint = on == true
	end)
	Net.on("Slide", function(player)
		local s = self:State(player)
		if os.clock() - s.slideAt >= Constants.SLIDE_COOLDOWN * 0.8 then
			s.slideAt = os.clock()
		end
	end)
	Net.on("Crouch", function(player, on)
		local s = self:State(player)
		s.crouch = on == true
		hipOf(player, s)
	end)
	local function watch(player)
		local function spawned(c)
			local s = self:State(player)
			s.crouch = false
			local hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
			s.baseHip = hum and hum.HipHeight or nil
		end
		player.CharacterAdded:Connect(spawned)
		if player.Character then
			task.spawn(spawned, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return MoveService

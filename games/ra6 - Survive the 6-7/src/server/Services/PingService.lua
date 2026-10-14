--[[
Quick pings for the team (master plan §12: a quick word without typing): "Help me!", "Loot here!", "KERMY!",
"Back to camp!". A ping marks a spot for everyone in the run (a beacon and an arrow at the screen edge for
PING_SECONDS) with a sound. The run's chat is Roblox's own.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PingService = {
	Name = "PingService",
	Dependencies = { "RunService", "SurvivorService" },
	Pinged = Signal.new("PingService.Pinged"), -- (player, key)
}

local runs, survivors
local last = {} -- [player] = time
local BY_KEY = {}
for _, p in Constants.PINGS do
	BY_KEY[p.key] = p
end

function PingService:Ping(player, key, position)
	local spec = BY_KEY[key]
	if not spec or not runs:InRun(player) then
		return false
	end
	local status = survivors:Status(player)
	if status ~= "alive" and status ~= "downed" then
		return false
	end
	local t = workspace:GetServerTimeNow()
	if t - (last[player] or -math.huge) < Constants.PING_COOLDOWN then
		return false
	end
	local pos = survivors:Position(player)
	if typeof(position) == "Vector3" and pos and (position - pos).Magnitude <= 300 then
		pos = position
	end
	if not pos then
		return false
	end
	last[player] = t
	local ping = {
		key = key,
		text = spec.text,
		icon = spec.icon,
		position = pos,
		from = player.DisplayName,
		userId = player.UserId,
		untilTime = t + Constants.PING_SECONDS,
	}
	for _, p in Players:GetPlayers() do
		if runs:InRun(p) then
			Net.fire(p, "Ping", ping)
		end
	end
	self.Pinged:Fire(player, key)
	return true
end

function PingService:Init(registry)
	runs = registry.RunService
	survivors = registry.SurvivorService
	Net.on("Ping", function(player, key, position)
		if type(key) == "string" then
			self:Ping(player, key, position)
		end
	end)
end

function PingService:OnPlayerLeaving(player)
	last[player] = nil
end

return PingService

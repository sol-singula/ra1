-- Quick pings for your team (master plan §19): "Help here!", "Gate is down!", "Monsters coming!", "Need stone!".
-- A ping marks a spot for your teammates only (a beacon and an arrow at the screen edge for PING_SECONDS) with a
-- sound. Team chat itself is Roblox's (the Teams service gives every team its own channel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PingService = {
	Name = "PingService",
	Dependencies = { "MatchService", "TeamService" },
	Pinged = Signal.new("PingService.Pinged"), -- (player, key)
}

local teams, match
local last = {} -- [player] = time
local BY_KEY = {}
for _, p in Constants.PINGS do
	BY_KEY[p.key] = p
end

function PingService:Ping(player, key, position)
	local spec = BY_KEY[key]
	local team = teams:Team(player)
	if not spec or not team or not match:InMatch() then
		return false
	end
	local t = workspace:GetServerTimeNow()
	if t - (last[player] or 0) < Constants.PING_COOLDOWN then
		return false
	end
	last[player] = t
	local pos = teams:Position(player)
	if typeof(position) == "Vector3" and pos and (position - pos).Magnitude <= 300 then
		pos = position
	end
	if not pos then
		return false
	end
	local ping = {
		key = key,
		text = spec.text,
		icon = spec.icon,
		position = pos,
		from = player.DisplayName,
		until_ = t + Constants.PING_SECONDS,
	}
	for _, p in game:GetService("Players"):GetPlayers() do
		if teams:Team(p) == team then
			Net.fire(p, "Ping", ping)
		end
	end
	self.Pinged:Fire(player, key)
	return true
end

function PingService:Init(reg)
	teams = reg.TeamService
	match = reg.MatchService
	Net.on("Ping", function(player, key, position)
		self:Ping(player, key, position)
	end)
end

function PingService:OnPlayerLeaving(player)
	last[player] = nil
end

return PingService

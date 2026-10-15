--[[
Visiting (master plan §5.5: your raft is yours; friends can come aboard). From the FRIENDS panel you take the
rowboat to someone's raft in this server (if they let you: friends, anyone or nobody), look around, fish from
their deck and ride along on their voyage; only the owner builds. Row home whenever you like; if the owner leaves,
everyone aboard goes home.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local VisitService = {
	Name = "VisitService",
	Dependencies = { "PlayerDataService", "RaftService", "PlayerService" },
	Visited = Signal.new("VisitService.Visited"), -- (player, host)
	Home = Signal.new("VisitService.Home"), -- (player, host)
	Permitted = Signal.new("VisitService.Permitted"), -- (player, mode)
}

local data, rafts, players
local visiting = {} -- [player] = host
local hosted = {} -- [host] = { [visitor userId] = true } this session

local function permitOf(host)
	local profile = data:Get(host)
	return profile and profile.permit or Constants.VISIT_DEFAULT
end

function VisitService:Host(player)
	return visiting[player]
end

-- Who's here and whether you may row over: the FRIENDS panel's list of rafts in this server.
function VisitService:Rafts(player)
	local out = {}
	for _, other in Players:GetPlayers() do
		local raft = rafts:RaftOf(other)
		if raft and other ~= player then
			local permit = permitOf(other)
			local okF, friend = pcall(player.IsFriendsWith, player, other.UserId)
			local allowed = permit == "anyone" or (permit == "friends" and okF and friend)
			table.insert(out, {
				userId = other.UserId,
				name = other.DisplayName,
				tier = raft.tier,
				tiles = raft.summary.tiles,
				permit = permit,
				allowed = allowed,
				friend = okF and friend or false,
				here = visiting[player] == other,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.allowed ~= b.allowed then
			return a.allowed
		end
		return a.name < b.name
	end)
	return out
end

function VisitService:Visit(player, userId)
	if userId == false or userId == nil then
		return self:GoHome(player)
	end
	local host = Players:GetPlayerByUserId(tonumber(userId) or 0)
	local raft = host and rafts:RaftOf(host)
	if not host or host == player or not raft then
		Net.fire(player, "Toast", "They're not in this server.", "bad")
		return false
	end
	local permit = permitOf(host)
	if permit == "nobody" then
		Net.fire(player, "Toast", `{host.DisplayName} isn't taking visitors.`, "bad")
		return false
	end
	if permit == "friends" then
		local ok, friend = pcall(player.IsFriendsWith, player, host.UserId)
		if not ok or not friend then
			Net.fire(player, "Toast", `{host.DisplayName}'s raft is friends only.`, "bad")
			return false
		end
	end
	if not players:IsAlive(player) then
		return false
	end
	visiting[player] = host
	Net.fire(player, "Fade", Constants.ROWBOAT_SECONDS, `Rowing over to {host.DisplayName}'s raft...`)
	task.delay(Constants.ROWBOAT_SECONDS * 0.5, function()
		if visiting[player] ~= host or not player.Parent or not host.Parent then
			return
		end
		players:SetVisiting(player, host)
		players:Teleport(player, rafts:SpawnPoint(raft) + Vector3.new(2, 0, 2))
		Net.fire(
			player,
			"Toast",
			`⛵ Welcome aboard {host.DisplayName}'s raft. Row home from the FRIENDS panel.`,
			"good"
		)
		Net.fire(host, "Toast", `👋 {player.DisplayName} rowed over to visit your raft.`, "info")
		hosted[host] = hosted[host] or {}
		if not hosted[host][player.UserId] then
			hosted[host][player.UserId] = true
			local profile = data:Get(host)
			if profile then
				profile.stats.visitors += 1
			end
		end
		local mine = data:Get(player)
		if mine then
			mine.stats.visits += 1
		end
		self.Visited:Fire(player, host)
	end)
	return true
end

function VisitService:GoHome(player)
	local host = visiting[player]
	if not host then
		return false
	end
	visiting[player] = nil
	Net.fire(player, "Fade", Constants.ROWBOAT_SECONDS, "Rowing home...")
	task.delay(Constants.ROWBOAT_SECONDS * 0.5, function()
		if not player.Parent or visiting[player] then
			return
		end
		players:SetVisiting(player, nil)
		local raft = rafts:RaftOf(player)
		if raft then
			players:Teleport(player, rafts:SpawnPoint(raft))
		end
		self.Home:Fire(player, host)
	end)
	return true
end

function VisitService:Permit(player, mode)
	if mode ~= "friends" and mode ~= "anyone" and mode ~= "nobody" then
		return false
	end
	local profile = data:Get(player)
	if not profile then
		return false
	end
	profile.permit = mode
	Net.fire(
		player,
		"Toast",
		mode == "nobody" and "🔒 Nobody can row over to your raft."
			or mode == "friends" and "👥 Friends can row over to your raft."
			or "🌊 Anyone in the server can row over to your raft.",
		"info"
	)
	game:GetService("ServerScriptService") -- (no-op)
	self.Permitted:Fire(player, mode)
	return true
end

function VisitService:Init(reg)
	data = reg.PlayerDataService
	rafts = reg.RaftService
	players = reg.PlayerService
	Net.on("Visit", function(player, userId)
		self:Visit(player, userId)
	end)
	Net.on("Permit", function(player, mode)
		self:Permit(player, mode)
	end)
	-- the host left: everyone aboard rows home
	rafts.Released:Connect(function(host)
		for player, h in visiting do
			if h == host and player.Parent then
				self:GoHome(player)
			end
		end
		hosted[host] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		visiting[player] = nil
	end)
end

return VisitService

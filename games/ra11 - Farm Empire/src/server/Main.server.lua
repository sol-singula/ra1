-- Server bootstrap: boot the services, then hand players to them once their save has loaded (OnPlayerLoaded: the
-- territory, the offline catch-up; OnPlayerReady: the first pushes to the client).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Loader = require(script.Parent.Loader)

Net.init()

local registry, order = Loader.boot(script.Parent.Services)
local PlayerDataService = registry.PlayerDataService

local function onPlayerAdded(player)
	local profile = PlayerDataService:Load(player)
	if not profile or not player.Parent then
		return
	end
	for _, svc in order do
		if svc.OnPlayerLoaded then
			local ok, err = xpcall(svc.OnPlayerLoaded, debug.traceback, svc, player, profile)
			if not ok then
				warn(`[{svc.Name}] OnPlayerLoaded failed: {err}`)
			end
		end
	end
	for _, svc in order do
		if svc.OnPlayerReady then
			local ok, err = xpcall(svc.OnPlayerReady, debug.traceback, svc, player, profile)
			if not ok then
				warn(`[{svc.Name}] OnPlayerReady failed: {err}`)
			end
		end
	end
end

local function onPlayerRemoving(player)
	local profile = PlayerDataService:Get(player)
	if profile then
		for i = #order, 1, -1 do -- reverse dependency order, before the final save
			local svc = order[i]
			if svc.OnPlayerLeaving then
				local ok, err = xpcall(svc.OnPlayerLeaving, debug.traceback, svc, player, profile)
				if not ok then
					warn(`[{svc.Name}] OnPlayerLeaving failed: {err}`)
				end
			end
		end
	end
	PlayerDataService:Release(player)
end

-- A rebuild (an admin reset, a prestige): the territory comes down and goes up again from the profile as it is now,
-- like leaving and joining without the save or the session seeing them go.
local KEEP = { AnalyticsService = true, OfflineService = true, LeaderboardService = true }
function PlayerDataService.Rebuild(player)
	local profile = PlayerDataService:Get(player)
	if not profile or not player.Parent then
		return false
	end
	for i = #order, 1, -1 do
		local svc = order[i]
		if svc.OnPlayerLeaving and not KEEP[svc.Name] then
			local ok, err = xpcall(svc.OnPlayerLeaving, debug.traceback, svc, player, profile)
			if not ok then
				warn(`[{svc.Name}] OnPlayerLeaving (rebuild) failed: {err}`)
			end
		end
	end
	for _, phase in { "OnPlayerLoaded", "OnPlayerReady" } do
		for _, svc in order do
			if svc[phase] and not KEEP[svc.Name] then
				local ok, err = xpcall(svc[phase], debug.traceback, svc, player, profile)
				if not ok then
					warn(`[{svc.Name}] {phase} (rebuild) failed: {err}`)
				end
			end
		end
	end
	return true
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	PlayerDataService:SaveAll()
end)

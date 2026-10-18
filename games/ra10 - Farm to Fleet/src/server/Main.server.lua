-- Server bootstrap: boot the services, then hand players to them once their save has loaded. The arena and the
-- first match come from MatchService:Start.
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
	-- (first, before anyone joins them to anything: the save is here; TutorialService takes a brand-new player to
	-- their private practice, BotService decides a takeover)
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

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	PlayerDataService:SaveAll()
end)

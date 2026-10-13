-- Server bootstrap: build the world, boot the services, then hand players to them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Loader = require(script.Parent.Loader)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

Net.init()

-- The Bonk Arena (its own place, or a reserved arena server of this one) runs its own small game: ArenaMain.
local ArenaMode = require(script.Parent.ArenaMode)
if ArenaMode.detect() then
	require(script.Parent.ArenaMain)()
	return
end

WorldBuilder.build()

local registry, order = Loader.boot(script.Parent.Services)
local PlayerDataService = registry.PlayerDataService

local function onPlayerAdded(player)
	-- fill the first servers first: a lower-numbered server with room gets this player, before the save loads
	local fill = registry.ServerFillService
	local target = fill and fill:TargetFor(player)
	if target and fill:Move(player, target) then
		local waited = 0
		while player.Parent and player:GetAttribute("FillMove") and waited < 15 do
			task.wait(0.5)
			waited += 0.5
		end
		if not player.Parent then
			return -- on their way
		end
	end
	local profile = PlayerDataService:Load(player)
	if not profile or not player.Parent then
		return
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

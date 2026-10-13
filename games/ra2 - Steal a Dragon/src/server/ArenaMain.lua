-- The Bonk Arena server: only profiles (to know your weapon and keep your KOs) and the arena itself.
local Players = game:GetService("Players")

local Loader = require(script.Parent.Loader)
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local ArenaService = require(script.Parent.Arena.ArenaService)

return function()
	workspace:SetAttribute("Arena", true)
	WorldBuilder.buildArena()
	local registry = Loader.boot(script.Parent.Services, { PlayerDataService = true })
	local PlayerDataService = registry.PlayerDataService
	ArenaService.init(registry)
	local function added(player)
		local profile = PlayerDataService:Load(player)
		if profile and player.Parent then
			ArenaService.join(player)
		end
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		ArenaService.leave(player)
		PlayerDataService:Release(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(added, player)
	end
	game:BindToClose(function()
		ArenaService.close()
		PlayerDataService:SaveAll()
	end)
end

--[[
Boots the server services in a fixed order.

  Loader.PLAN    every service the game will have, in boot order
  Loader.ORDER   the services that exist so far (each milestone adds its own as it creates them); always in PLAN
                 order
  Loader.boot(folder, order)    requires each name in order from folder (a missing module is an error), then
                                Loader.start
  Loader.start(modules, order)  runs the hooks; returns the services table

Hooks, all optional, called as methods:
  Service:Init(services)                    in order; an error aborts the boot
  Service:Start()                           after every Init, each in its own task.spawn
  Service:OnPlayerLoaded(player, profile)   on DataService.Loaded
  Service:OnPlayerLeaving(player, profile)  on DataService.Leaving
]]
local Loader = {}

Loader.PLAN = {
	"DataService",
	"NetService",
	"PolicyGate",
	"WeeklyService",
	"PlotService",
	"FarmService",
	"ShopService",
	"BlockPartyService",
	"WeatherService",
	"MutationService",
	"InventoryService",
	"CollectionLogService",
	"RewardService",
	"SocialService",
	"LeaderboardService",
	"PurchaseService",
	"PatchService",
	"LoungeService",
	"TelemetryService",
	"FirstSessionService",
	"CaptureService",
}

Loader.ORDER = {
	"DataService",
	"NetService",
}

local function forEachHook(services, order, hook, ...)
	for _, name in order do
		local service = services[name]
		if type(service[hook]) == "function" then
			task.spawn(service[hook], service, ...)
		end
	end
end

function Loader.start(modules, order)
	local services = {}
	for _, name in order do
		services[name] = modules[name]
	end
	for _, name in order do
		local service = services[name]
		if type(service.Init) == "function" then
			local ok, err = pcall(service.Init, service, services)
			if not ok then
				error(`[Loader] {name}: {err}`, 0)
			end
		end
	end
	for _, name in order do
		local service = services[name]
		if type(service.Start) == "function" then
			task.spawn(service.Start, service)
		end
	end
	local data = services.DataService
	if data and data.Loaded then
		data.Loaded:Connect(function(player, profile)
			forEachHook(services, order, "OnPlayerLoaded", player, profile)
		end)
	end
	if data and data.Leaving then
		data.Leaving:Connect(function(player, profile)
			forEachHook(services, order, "OnPlayerLeaving", player, profile)
		end)
	end
	print("[Loader] ready")
	return services
end

function Loader.boot(folder, order)
	local modules = {}
	for _, name in order do
		local module = folder:FindFirstChild(name)
		if not module then
			error(`[Loader] {name}: missing module`, 0)
		end
		modules[name] = require(module)
	end
	return Loader.start(modules, order)
end

return Loader

--[[
Boots the client controllers in a fixed order; the client mirror of the server Loader.

  ControllerLoader.ORDER   the controllers that exist so far (each milestone adds its own)
  ControllerLoader.boot(folder, order)    requires each name in order from folder (a missing module is an error)
  ControllerLoader.start(modules, order)  runs the hooks; returns the controllers table

Hooks, all optional, called as methods: Init(controllers) in order (an error aborts the boot), then Start() each
in its own task.spawn. OnPlayerLoaded(player, profile) / OnPlayerLeaving(player, profile) are wired to
ProfileController.Loaded / .Leaving once it exists.
]]
local ControllerLoader = {}

ControllerLoader.ORDER = {
	"StateController",
	"HudController",
	"TileController",
	"UpgradeController",
	"SellController",
	"WelcomeBackController",
	"BlockPartyController",
	"WeatherController",
	"BackpackController",
	"PedestalController",
	"ShopController",
	"PatchController",
	"OddsController",
	"CollectionController",
	"DailyController",
	"QuestController",
	"PlaytimeController",
	"UpdateBoardController",
	"LeaderboardController",
	"CaptureController",
}

local function forEachHook(controllers, order, hook, ...)
	for _, name in order do
		local controller = controllers[name]
		if type(controller[hook]) == "function" then
			task.spawn(controller[hook], controller, ...)
		end
	end
end

function ControllerLoader.start(modules, order)
	local controllers = {}
	for _, name in order do
		controllers[name] = modules[name]
	end
	for _, name in order do
		local controller = controllers[name]
		if type(controller.Init) == "function" then
			local ok, err = pcall(controller.Init, controller, controllers)
			if not ok then
				error(`[ControllerLoader] {name}: {err}`, 0)
			end
		end
	end
	for _, name in order do
		local controller = controllers[name]
		if type(controller.Start) == "function" then
			task.spawn(controller.Start, controller)
		end
	end
	local profile = controllers.ProfileController
	if profile and profile.Loaded then
		profile.Loaded:Connect(function(player, data)
			forEachHook(controllers, order, "OnPlayerLoaded", player, data)
		end)
	end
	if profile and profile.Leaving then
		profile.Leaving:Connect(function(player, data)
			forEachHook(controllers, order, "OnPlayerLeaving", player, data)
		end)
	end
	print("[ControllerLoader] ready")
	return controllers
end

function ControllerLoader.boot(folder, order)
	local modules = {}
	for _, name in order do
		local module = folder:FindFirstChild(name)
		if not module then
			error(`[ControllerLoader] {name}: missing module`, 0)
		end
		modules[name] = require(module)
	end
	return ControllerLoader.start(modules, order)
end

return ControllerLoader

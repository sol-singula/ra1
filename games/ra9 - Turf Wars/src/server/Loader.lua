-- Service loader: requires every service module, sorts them by Dependencies,
-- then runs Init (must not yield) and Start (own thread) in that order. Errors are isolated per service.
--
-- Modes (Data/Modes): a service may declare Modes = { "turf", "ctf" } (the modes it runs in; none: every mode).
-- In a place of another mode it isn't booted, and nor is a service whose every dependency is skipped. A skipped
-- service is simply nil in the registry: a service that runs in more modes than one it depends on must nil-check
-- that lookup (registry.MatchService and registry.MatchService:Phase() ...), in Init and after.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Modes = require(ReplicatedStorage.Shared.Data.Modes)

local Loader = {}

local function sorted(services, skipped)
	local order, state = {}, {}
	local function visit(name, path)
		local svc = services[name]
		if not svc and skipped[name] then
			return -- (not in this mode: nil in the registry)
		end
		assert(svc, `unknown dependency '{name}' via {table.concat(path, " -> ")}`)
		if state[name] == 2 then
			return
		end
		assert(state[name] ~= 1, `dependency cycle: {table.concat(path, " -> ")} -> {name}`)
		state[name] = 1
		table.insert(path, name)
		for _, dep in svc.Dependencies or {} do
			visit(dep, path)
		end
		table.remove(path)
		state[name] = 2
		table.insert(order, svc)
	end
	local names = {}
	for n in services do
		table.insert(names, n)
	end
	table.sort(names) -- deterministic boot order
	for _, n in names do
		visit(n, {})
	end
	return order
end

-- Which of these services boot in a mode: the ones for it, less any whose dependencies are all skipped.
-- Returns the set to run and the set skipped (name -> true).
function Loader.select(services, mode)
	mode = mode or Constants.MODE
	local run, skipped = {}, {}
	for name, svc in services do
		if Modes.runsIn(svc, mode) then
			run[name] = svc
		else
			skipped[name] = true
		end
	end
	local again = true
	while again do
		again = false
		for name, svc in run do
			local deps = svc.Dependencies or {}
			local allGone = #deps > 0
			for _, dep in deps do
				if not skipped[dep] then
					allGone = false
					break
				end
			end
			if allGone then
				run[name], skipped[name] = nil, true
				again = true
			end
		end
	end
	return run, skipped
end

-- Returns the registry (name -> service) and the boot order. With `only` (a set of names), just those services
-- (the Bonk Arena runs a small set). mode: which place this is (default Constants.MODE).
function Loader.boot(folder, only, mode)
	mode = mode or Constants.MODE
	local all = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and (not only or only[child.Name]) then
			local svc = require(child)
			all[svc.Name] = svc
		end
	end
	local services, skipped = Loader.select(all, mode)
	local registry = table.clone(services)
	local names = {}
	for name in skipped do
		table.insert(names, name)
	end
	if #names > 0 then
		table.sort(names)
		print(`[Loader] {mode}: not running {table.concat(names, ", ")}`)
	end
	local order = sorted(services, skipped)
	for _, svc in order do
		if svc.Init then
			local co = coroutine.create(svc.Init)
			local ok, err = coroutine.resume(co, svc, registry)
			if ok and coroutine.status(co) ~= "dead" then
				ok, err = false, "Init yielded"
			end
			if not ok then
				error(`[{svc.Name}] Init failed: {debug.traceback(co, tostring(err))}`)
			end
		end
	end
	for _, svc in order do
		if svc.Start then
			task.spawn(function()
				local ok, err = xpcall(svc.Start, debug.traceback, svc)
				if not ok then
					warn(`[{svc.Name}] Start failed: {err}`)
				end
			end)
		end
	end
	return registry, order
end

return Loader

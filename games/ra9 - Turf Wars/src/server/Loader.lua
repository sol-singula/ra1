-- Service loader: requires every service module, sorts them by Dependencies,
-- then runs Init (must not yield) and Start (own thread) in that order. Errors are isolated per service.
-- A service that names its Modes (e.g. { "lobby" }) only boots when Constants.MODE is one of them; a dependency
-- that was left out that way (or by `only`) is skipped, so the service must do without it (registry[name] is nil).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Loader = {}

local function sorted(services, skipped)
	local order, state = {}, {}
	local function visit(name, path)
		local svc = services[name]
		if not svc and skipped[name] then
			return -- (not in this place or this set: the service copes without it)
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

-- Returns the registry (name -> service) and the boot order. With `only` (a set of names), just those services
-- (the Bonk Arena runs a small set).
function Loader.boot(folder, only)
	local services, registry, skipped = {}, {}, {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			if only and not only[child.Name] then
				skipped[child.Name] = true
			else
				local svc = require(child)
				if svc.Modes and not table.find(svc.Modes, Constants.MODE) then
					skipped[svc.Name] = true -- (another place's service)
				else
					services[svc.Name] = svc
					registry[svc.Name] = svc
				end
			end
		end
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

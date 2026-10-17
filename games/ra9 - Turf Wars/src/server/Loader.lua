-- Service loader: requires every service module, sorts them by Dependencies,
-- then runs Init (must not yield) and Start (own thread) in that order. Errors are isolated per service.
--
-- Modes (Constants.MODE: the place this server is): a service may declare Modes = { "lobby", ... } and runs only
-- in those. In the lobby, a service that declares nothing runs only when a lobby service depends on it (so the
-- match, the bots and the arena stay out of the lobby); in a match mode everything runs. (A stub until the
-- framework's version lands.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Loader = {}

-- The services that run in this mode (see above).
local function forMode(services, mode)
	local keep = {}
	local declared = {}
	for name, svc in services do
		if type(svc.Modes) == "table" then
			declared[name] = true
			if table.find(svc.Modes, mode) then
				keep[name] = true
			end
		elseif mode ~= "lobby" then
			keep[name] = true
		end
	end
	-- (the lobby: what its services depend on comes along, and what those depend on)
	local todo = {}
	for name in keep do
		table.insert(todo, name)
	end
	while #todo > 0 do
		local name = table.remove(todo)
		for _, dep in (services[name] and services[name].Dependencies) or {} do
			if not keep[dep] and not declared[dep] then
				keep[dep] = true
				table.insert(todo, dep)
			end
		end
	end
	local out = {}
	for name, svc in services do
		if keep[name] then
			out[name] = svc
		end
	end
	return out
end

local function sorted(services)
	local order, state = {}, {}
	local function visit(name, path)
		local svc = services[name]
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
	local services = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and (not only or only[child.Name]) then
			local svc = require(child)
			services[svc.Name] = svc
		end
	end
	services = forMode(services, Constants.MODE)
	local registry = table.clone(services)
	local order = sorted(services)
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

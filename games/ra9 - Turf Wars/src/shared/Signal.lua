-- Server-to-server and client-local events. Each handler runs in its own thread under xpcall,
-- so one faulty subscriber cannot break the publisher or the other subscribers.
local Signal = {}
Signal.__index = Signal

local function run(name, fn, ...)
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		warn(`[Signal {name}] {err}`)
	end
end

function Signal.new(name)
	return setmetatable({ _name = name or "Signal", _conns = {} }, Signal)
end

function Signal:Connect(fn)
	local conns = self._conns
	local conn = { Connected = true, _fn = fn }
	function conn.Disconnect(c)
		if not c.Connected then
			return
		end
		c.Connected = false
		local i = table.find(conns, c)
		if i then
			table.remove(conns, i)
		end
	end
	table.insert(conns, conn)
	return conn
end

function Signal:Fire(...)
	for _, c in table.clone(self._conns) do
		if c.Connected then
			task.spawn(run, self._name, c._fn, ...)
		end
	end
end

return Signal

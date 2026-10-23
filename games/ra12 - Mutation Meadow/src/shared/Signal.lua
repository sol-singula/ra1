--[[
A plain Lua signal (no BindableEvents, so tables pass through untouched).

  Signal.new()
  signal:Connect(fn)     -> connection (connection:Disconnect())
  signal:Once(fn)        -> connection; fires fn at most once
  signal:Wait()          yields until the next Fire, returns its arguments
  signal:Fire(...)       runs every listener connected at the moment of the call, each in its own task.spawn
  signal:DisconnectAll()
]]
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._listeners
	local i = table.find(list, self)
	if i then
		table.remove(list, i)
	end
end

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = setmetatable({ Connected = true, _signal = self, _fn = fn }, Connection)
	table.insert(self._listeners, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	-- a snapshot: listeners connected while firing wait for the next Fire; ones disconnected while firing are skipped
	for _, connection in table.clone(self._listeners) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, connection in self._listeners do
		connection.Connected = false
	end
	table.clear(self._listeners)
end

return Signal

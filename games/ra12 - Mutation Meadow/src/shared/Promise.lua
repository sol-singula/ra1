--[[
A minimal one-shot promise: resolved once with one value; anyone can wait for it.

  Promise.new()             -> promise
  Promise.resolved(value)   -> an already-resolved promise
  promise:resolve(value)    the first call wins; later calls are ignored
  promise:await()           yields until resolved, returns the value (returns at once if already resolved)
  promise:andThen(fn)       calls fn(value) once resolved (in its own task.spawn); returns the promise
  promise.done / promise.value
]]
local Promise = {}
Promise.__index = Promise

function Promise.new()
	return setmetatable({ done = false, value = nil, _threads = {}, _callbacks = {} }, Promise)
end

function Promise.resolved(value)
	local p = Promise.new()
	p:resolve(value)
	return p
end

function Promise:resolve(value)
	if self.done then
		return
	end
	self.done = true
	self.value = value
	local threads, callbacks = self._threads, self._callbacks
	self._threads, self._callbacks = {}, {}
	for _, thread in threads do
		task.spawn(thread, value)
	end
	for _, fn in callbacks do
		task.spawn(fn, value)
	end
end

function Promise:await()
	if self.done then
		return self.value
	end
	table.insert(self._threads, coroutine.running())
	return coroutine.yield()
end

function Promise:andThen(fn)
	if self.done then
		task.spawn(fn, self.value)
	else
		table.insert(self._callbacks, fn)
	end
	return self
end

return Promise

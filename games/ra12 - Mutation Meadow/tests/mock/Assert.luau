--[[
Assertions and the test collector.

  Assert.eq(a, b, msg)          deep equality
  Assert.near(a, b, tol, msg)   |a - b| <= tol (default 1e-9)
  Assert.truthy(v, msg)
  Assert.throws(fn, pattern?)   fn must error (and the message match pattern, when given); returns the message
  Assert.test(name, fn)         registers a test; tests/run.luau runs them
]]
local Assert = {}

Assert.tests = {}

local function show(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function deepEq(a, b, path)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false, `{path}: {show(a)} ~= {show(b)}`
	end
	for k, v in a do
		local ok, why = deepEq(v, b[k], path .. "." .. tostring(k))
		if not ok then
			return false, why
		end
	end
	for k, v in b do
		if a[k] == nil then
			return false, `{path}.{tostring(k)}: nil ~= {show(v)}`
		end
	end
	return true
end

function Assert.eq(a, b, msg)
	local ok, why = deepEq(a, b, "value")
	if not ok then
		error((msg and msg .. ": " or "") .. why, 2)
	end
end

function Assert.near(a, b, tol, msg)
	tol = tol or 1e-9
	if type(a) ~= "number" or type(b) ~= "number" or math.abs(a - b) > tol then
		error((msg and msg .. ": " or "") .. `{show(a)} not within {tol} of {show(b)}`, 2)
	end
end

function Assert.truthy(v, msg)
	if not v then
		error(msg or `expected a truthy value, got {show(v)}`, 2)
	end
end

function Assert.throws(fn, pattern)
	local ok, err = pcall(fn)
	if ok then
		error("expected an error", 2)
	end
	err = tostring(err)
	if pattern and not err:find(pattern) then
		error(`error {show(err)} does not match {show(pattern)}`, 2)
	end
	return err
end

function Assert.test(name, fn)
	table.insert(Assert.tests, { name = name, fn = fn })
end

return Assert

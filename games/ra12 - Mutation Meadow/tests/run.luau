-- Runs every tests/*.spec.luau and exits non-zero on any failure. Run from the game folder: tools/run_tests.sh
local fs = require("@lune/fs")
local process = require("@lune/process")

local Assert = require("./mock/Assert")

local started = os.clock()
local files = {}
for _, name in fs.readDir("tests") do
	if name:match("%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

local passed, failed = 0, 0
for _, file in files do
	local before = #Assert.tests
	local path = "./" .. file:gsub("%.luau$", "")
	local ok, err = pcall(function()
		return require(path)
	end)
	if not ok then
		failed += 1
		print(`FAIL {file} (load): {err}`)
	end
	for i = before + 1, #Assert.tests do
		local t = Assert.tests[i]
		local tok, terr = xpcall(t.fn, debug.traceback)
		if tok then
			passed += 1
		else
			failed += 1
			print(`FAIL {file} > {t.name}\n  {terr}`)
		end
	end
end

print(`{passed} passed, {failed} failed in {string.format("%.2f", os.clock() - started)}s`)
process.exit(failed == 0 and 0 or 1)

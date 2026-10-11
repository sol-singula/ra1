-- Short number and time text: 1.2K, 3.4M, 0:42, 3h 5m.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn" }

function Format.num(n)
	n = math.floor(n or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local x = n
	while math.abs(x) >= 1000 and i < #SUFFIXES do
		x /= 1000
		i += 1
	end
	local text = math.abs(x) >= 100 and string.format("%d", math.floor(x))
		or string.format("%.1f", math.floor(x * 10) / 10)
	text = text:gsub("%.0$", "")
	return text .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.commas(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Format.time(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format

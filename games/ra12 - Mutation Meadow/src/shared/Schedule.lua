--[[
The calendar (pure, §6). Times are Unix seconds (UTC).

  Schedule.hourStart(t)                  the start of t's UTC hour (the Block Party window)
  Schedule.restockSlot(t)                t // Config.Restock.intervalSec
  Schedule.slotEndsAt(slot)              (slot + 1) x intervalSec
  Schedule.daysFromCivil(y, m, d)        days since 1970-01-01
  Schedule.civilFromDays(days)           y, m, d
  Schedule.weekday(days)                 1 = Sunday .. 7 = Saturday
  Schedule.isDst(y, m, d)                US daylight time on that date: from the second Sunday of March to the first
                                         Sunday of November
  Schedule.weeklyStartUtc(y, m, d)       10:00 Mountain on that date: Config.Weekly.utcHourDst (16:00 UTC) in daylight
                                         time, utcHourStd (17:00 UTC) otherwise. Never a fixed offset.
  Schedule.currentUpdate(t)              { updateId = "YYYY-MM-DD", startsAt, nextAt }: the latest weekly start <= t
  Schedule.isEventWeek(updateId)         the update falls on day 1..Config.Weekly.eventWeekMaxDay of its month
]]
local Config = require(script.Parent.Config)

local Schedule = {}

local DAY = 86400
local HOUR = 3600
local WEEK = 7

function Schedule.hourStart(t)
	return t // HOUR * HOUR
end

function Schedule.restockSlot(t)
	return t // Config.Restock.intervalSec
end

function Schedule.slotEndsAt(slot)
	return (slot + 1) * Config.Restock.intervalSec
end

-- Howard Hinnant's days_from_civil / civil_from_days
function Schedule.daysFromCivil(y, m, d)
	y = if m <= 2 then y - 1 else y
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function Schedule.civilFromDays(z)
	z += 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	return (if m <= 2 then y + 1 else y), m, d
end

function Schedule.weekday(days)
	return (days + 4) % 7 + 1 -- 1970-01-01 was a Thursday (5)
end

-- the date (day number) of the nth Sunday of a month
local function nthSunday(y, m, n)
	local first = Schedule.daysFromCivil(y, m, 1)
	local toSunday = (8 - Schedule.weekday(first)) % 7
	return first + toSunday + (n - 1) * WEEK
end

function Schedule.isDst(y, m, d)
	local day = Schedule.daysFromCivil(y, m, d)
	return day >= nthSunday(y, 3, 2) and day < nthSunday(y, 11, 1)
end

function Schedule.weeklyStartUtc(y, m, d)
	local hour = if Schedule.isDst(y, m, d) then Config.Weekly.utcHourDst else Config.Weekly.utcHourStd
	return Schedule.daysFromCivil(y, m, d) * DAY + hour * HOUR
end

local function startOfDay(days)
	local y, m, d = Schedule.civilFromDays(days)
	return Schedule.weeklyStartUtc(y, m, d), y, m, d
end

function Schedule.currentUpdate(t)
	local today = t // DAY
	local back = (Schedule.weekday(today) - Config.Weekly.dayOfWeek) % WEEK
	local day = today - back
	local startsAt, y, m, d = startOfDay(day)
	if startsAt > t then
		day -= WEEK
		startsAt, y, m, d = startOfDay(day)
	end
	return {
		updateId = string.format("%04d-%02d-%02d", y, m, d),
		startsAt = startsAt,
		nextAt = (startOfDay(day + WEEK)),
	}
end

function Schedule.isEventWeek(updateId)
	local d = tonumber(updateId:match("^%d%d%d%d%-%d%d%-(%d%d)$"))
	return d ~= nil and d <= Config.Weekly.eventWeekMaxDay
end

return Schedule

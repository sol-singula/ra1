local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Schedule = engine:require(engine:module("Shared/Schedule"))

local function utc(y, m, d, h, mi, s)
	return Schedule.daysFromCivil(y, m, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0)
end

test("§6 vectors: 16:00Z in daylight time, 17:00Z otherwise", function()
	eq(Schedule.weeklyStartUtc(2026, 10, 24), utc(2026, 10, 24, 16))
	eq(Schedule.weeklyStartUtc(2026, 10, 31), utc(2026, 10, 31, 16))
	eq(Schedule.weeklyStartUtc(2026, 11, 7), utc(2026, 11, 7, 17))
	eq(Schedule.weeklyStartUtc(2027, 3, 13), utc(2027, 3, 13, 17))
	eq(Schedule.weeklyStartUtc(2027, 3, 20), utc(2027, 3, 20, 16))
end)

test("dates and weekdays", function()
	eq(Schedule.daysFromCivil(1970, 1, 1), 0)
	eq({ Schedule.civilFromDays(Schedule.daysFromCivil(2026, 10, 24)) }, { 2026, 10, 24 })
	eq({ Schedule.civilFromDays(Schedule.daysFromCivil(2028, 2, 29)) }, { 2028, 2, 29 })
	eq(Schedule.weekday(Schedule.daysFromCivil(2026, 10, 24)), 7, "a Saturday")
	eq(Schedule.weekday(Schedule.daysFromCivil(2026, 11, 1)), 1, "a Sunday")
	eq({
		Schedule.isDst(2026, 3, 7),
		Schedule.isDst(2026, 3, 8),
		Schedule.isDst(2026, 10, 31),
		Schedule.isDst(2026, 11, 1),
	}, { false, true, true, false })
end)

test("currentUpdate: the latest Saturday start <= t", function()
	local before = Schedule.currentUpdate(utc(2026, 10, 24, 15, 59, 59))
	eq(before.updateId, "2026-10-17")
	eq(before.startsAt, utc(2026, 10, 17, 16))
	eq(before.nextAt, utc(2026, 10, 24, 16))
	local at = Schedule.currentUpdate(utc(2026, 10, 24, 16))
	eq(at.updateId, "2026-10-24")
	eq(at.nextAt, utc(2026, 10, 31, 16))
	local across = Schedule.currentUpdate(utc(2026, 11, 3, 12))
	eq(across.updateId, "2026-10-31")
	eq(across.nextAt, utc(2026, 11, 7, 17), "the switch back to standard time")
	eq(Schedule.currentUpdate(utc(2026, 11, 7, 16, 30)).updateId, "2026-10-31", "17:00Z that week")
end)

test("event weeks: the first Saturday of the month", function()
	eq(
		{ Schedule.isEventWeek("2026-11-07"), Schedule.isEventWeek("2026-12-05"), Schedule.isEventWeek("2027-01-02") },
		{ true, true, true }
	)
	eq({ Schedule.isEventWeek("2026-10-31"), Schedule.isEventWeek("2026-10-24") }, { false, false })
end)

test("hours and restock slots", function()
	eq(Schedule.hourStart(utc(2026, 10, 24, 15, 59, 59)), utc(2026, 10, 24, 15))
	eq(Schedule.restockSlot(599), 1)
	eq(Schedule.restockSlot(600), 2)
	eq(Schedule.slotEndsAt(2), 900)
end)

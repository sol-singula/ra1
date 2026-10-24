local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local BundleReview = engine:require(engine:module("Shared/BundleReview"))
local Config = engine:require(engine:module("Shared/Config"))

-- one bundle sale and `other` Robux of repeat offers on each day from..to
local function days(from, to, bundle, other)
	local rows = {}
	for day = from, to do
		table.insert(rows, { day = day, key = "starterBundle", robux = bundle })
		table.insert(rows, { day = day, key = "instantGrow", robux = other })
	end
	return rows
end

test("the thresholds live in Config", function()
	eq(Config.Catalog.bundleReview, {
		startDay = 14,
		windowDays = 7,
		highShare = 0.50,
		lowShare = 0.10,
		repeatOffers = { "instantGrow", "growAll", "cosmetics", "gifts" },
	})
end)

test("over 50% from day 14: review the repeat offers; nothing before day 14", function()
	local rows = days(1, 30, 249, 100)
	eq(BundleReview.evaluate(rows, 13), nil, "day 13 is too early")
	local flag, info = BundleReview.evaluate(rows, 14)
	eq(flag, "review_repeat_offers")
	eq({ info.from, info.to, info.bundle, info.total }, { 8, 14, 249 * 7, 349 * 7 })
end)

test("under 10%: check the bundle is seen; 10% to 50%: no flag", function()
	eq(BundleReview.evaluate(days(1, 20, 249, 2300), 20), "check_bundle_visibility")
	eq(BundleReview.evaluate(days(1, 20, 249, 249), 20), nil, "exactly 50%")
	eq(BundleReview.evaluate(days(1, 20, 100, 900), 20), nil, "exactly 10%")
	eq(BundleReview.evaluate({}, 20), nil, "no Robux in the window")
end)

test("the window rolls: only the last 7 days count", function()
	local rows = days(1, 10, 249, 0) -- bundle-only early on
	for _, row in days(11, 20, 0, 100) do
		table.insert(rows, row)
	end
	local flag, info = BundleReview.evaluate(rows, 17)
	eq({ flag, info.from, info.bundle }, { "check_bundle_visibility", 11, 0 })
	eq(BundleReview.evaluate(rows, 14), "review_repeat_offers", "days 8-10 bundle (747), 11-14 Instant Grow (400): 65%")
end)

test("retuned thresholds are honoured", function()
	local cfg = { startDay = 1, windowDays = 3, highShare = 0.9, lowShare = 0.6 }
	eq(BundleReview.evaluate(days(1, 5, 249, 100), 3, cfg), nil)
	eq(BundleReview.evaluate(days(1, 5, 100, 249), 3, cfg), "check_bundle_visibility")
end)

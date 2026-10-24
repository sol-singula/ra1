--[[
The Starter Bundle revenue check (pure; docs/analytics.md). Thresholds are Config.Catalog.bundleReview.

rows are exported purchase events: { day, key, robux }, day 1 = launch day. On day `today` (from startDay on) it
sums the rows of the last windowDays days (today - windowDays + 1 .. today): the bundle's share is
purchase:starterBundle Robux over all purchase Robux.

  share > highShare   "review_repeat_offers"     the bundle carries revenue: look at Instant Grow, Grow All,
                                                 cosmetics and gifts, not the bundle
  share < lowShare    "check_bundle_visibility"  are players seeing the bundle?
  otherwise, before startDay, or with no Robux in the window: nil

  BundleReview.evaluate(rows, today, cfg?) -> flag?, { share, bundle, total, from, to }
]]
local Config = require(script.Parent.Config)

local BundleReview = {}

BundleReview.BUNDLE_KEY = "starterBundle"

function BundleReview.evaluate(rows, today, cfg)
	cfg = cfg or Config.Catalog.bundleReview
	local from = today - cfg.windowDays + 1
	local bundle, total = 0, 0
	for _, row in rows do
		if row.day >= from and row.day <= today then
			total += row.robux
			if row.key == BundleReview.BUNDLE_KEY then
				bundle += row.robux
			end
		end
	end
	local share = if total > 0 then bundle / total else nil
	local info = { share = share, bundle = bundle, total = total, from = from, to = today }
	if today < cfg.startDay or not share then
		return nil, info
	elseif share > cfg.highShare then
		return "review_repeat_offers", info
	elseif share < cfg.lowShare then
		return "check_bundle_visibility", info
	end
	return nil, info
end

return BundleReview

--[[
Your home on the farm: where you sleep. It starts as a one-room shack and grows with the farm, bought on the
buy-pads like any upgrade (Data/Upgrades kind "home"), until it's a mansion with a fountain and a pool beside the
whole operation. Walk in through the front door; the roof lifts while you're inside.

Sleeping (the bed's prompt, HomeService): every crop on the farm ripens at once and you wake up Well Rested
(everything shipped pays RESTED_BONUS more for RESTED_SECONDS); the bed needs NAP_COOLDOWN seconds between naps
(less in a bigger home).

  Home.TIERS[n]     { key, name, w, d, h, wall, trim, roof, upgrade (its key, nil for the shack) }
  Home.tier(owned)  the home they have (1..#TIERS)
  Home.cooldown(tier)
]]
local Home = {}

Home.RESTED_SECONDS = 180
Home.RESTED_BONUS = 0.25
Home.NAP_COOLDOWN = 240

-- stylua: ignore start
Home.TIERS = {
	{ key = "shack",     name = "The Shack",       w = 16, d = 12, h = 8,  wall = Color3.fromRGB(190, 60, 50),   trim = Color3.fromRGB(245, 240, 225), roof = Color3.fromRGB(45, 45, 52) },
	{ key = "cottage",   name = "Cozy Cottage",    w = 20, d = 14, h = 9,  wall = Color3.fromRGB(250, 220, 150), trim = Color3.fromRGB(255, 255, 250), roof = Color3.fromRGB(70, 120, 190), upgrade = "cottage" },
	{ key = "farmhouse", name = "The Farmhouse",   w = 24, d = 16, h = 10, wall = Color3.fromRGB(245, 245, 240), trim = Color3.fromRGB(60, 120, 80),   roof = Color3.fromRGB(160, 60, 50),  upgrade = "farmhouse" },
	{ key = "villa",     name = "The Villa",       w = 28, d = 18, h = 12, wall = Color3.fromRGB(240, 215, 185), trim = Color3.fromRGB(255, 250, 240), roof = Color3.fromRGB(190, 95, 60),  upgrade = "villa" },
	{ key = "mansion",   name = "The Mansion",     w = 34, d = 22, h = 14, wall = Color3.fromRGB(250, 248, 242), trim = Color3.fromRGB(40, 50, 70),    roof = Color3.fromRGB(50, 60, 80),   upgrade = "mansion" },
	{ key = "estate",    name = "The Grand Estate", w = 38, d = 24, h = 15, wall = Color3.fromRGB(252, 250, 246), trim = Color3.fromRGB(200, 165, 70),  roof = Color3.fromRGB(35, 45, 70),   upgrade = "estate" },
}
-- stylua: ignore end

function Home.tier(owned)
	local t = 1
	for i, tier in Home.TIERS do
		if tier.upgrade and owned and owned[tier.upgrade] then
			t = math.max(t, i)
		end
	end
	return t
end

function Home.cooldown(tier)
	return math.floor(Home.NAP_COOLDOWN * (1 - 0.12 * ((tier or 1) - 1)))
end

return Home

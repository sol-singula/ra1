--[[
Your home on the farm. It starts as a one-room shack and grows with the farm until it's a mansion with a garden,
trees and a fountain beside the whole operation (World/FarmBuilder.homeTier builds each).

It grows with the farm level, by itself (no buying): the farm pays for the home.

  Home.TIERS[n]     { key, name, level, w, d, h, wall, trim, roof }
  Home.tier(level)  the home a farm level has (1..#TIERS)
]]
local Home = {}

-- stylua: ignore start
Home.TIERS = {
	{ key = "shack", level = 1,     name = "The Shack",       w = 16, d = 12, h = 8,  wall = Color3.fromRGB(190, 60, 50),   trim = Color3.fromRGB(245, 240, 225), roof = Color3.fromRGB(45, 45, 52) },
	{ key = "cottage", level = 6,   name = "Cozy Cottage",    w = 20, d = 14, h = 9,  wall = Color3.fromRGB(250, 220, 150), trim = Color3.fromRGB(255, 255, 250), roof = Color3.fromRGB(70, 120, 190) },
	{ key = "farmhouse", level = 12, name = "The Farmhouse",   w = 24, d = 16, h = 10, wall = Color3.fromRGB(245, 245, 240), trim = Color3.fromRGB(60, 120, 80),   roof = Color3.fromRGB(160, 60, 50),  upgrade = "farmhouse" },
	{ key = "villa", level = 18,     name = "The Villa",       w = 28, d = 18, h = 12, wall = Color3.fromRGB(240, 215, 185), trim = Color3.fromRGB(255, 250, 240), roof = Color3.fromRGB(190, 95, 60),  upgrade = "villa" },
	{ key = "mansion", level = 25,   name = "The Mansion",     w = 34, d = 22, h = 14, wall = Color3.fromRGB(250, 248, 242), trim = Color3.fromRGB(40, 50, 70),    roof = Color3.fromRGB(50, 60, 80),   upgrade = "mansion" },
	{ key = "estate", level = 32,    name = "The Grand Estate", w = 38, d = 24, h = 15, wall = Color3.fromRGB(252, 250, 246), trim = Color3.fromRGB(200, 165, 70),  roof = Color3.fromRGB(35, 45, 70),   upgrade = "estate" },
}
-- stylua: ignore end

function Home.tier(level)
	local t = 1
	for i, tier in Home.TIERS do
		if (level or 1) >= tier.level then
			t = i
		end
	end
	return t
end

return Home

-- Blaster rarities. A blaster is a rarity plus the planet whose ore forged it: "Frost Cannon" is an Epic from Ice.
-- Base damage is per planet (Planets.bugHealth / 10 or so), times the rarity's multiplier, times the rolls.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Blasters = {}

Blasters.Rarities = {
	{ key = "Common", noun = "Zapper", mult = 1, color = rgb(190, 190, 200), glow = false, sell = 10 },
	{ key = "Rare", noun = "Blaster", mult = 2, color = rgb(70, 170, 255), glow = false, sell = 40 },
	{ key = "Epic", noun = "Cannon", mult = 4, color = rgb(190, 90, 255), glow = true, sell = 200 },
	{ key = "Legend", noun = "Nova Cannon", mult = 9, color = rgb(255, 180, 40), glow = true, sell = 1500 },
	{ key = "Secret", noun = "Star Breaker", mult = 20, color = rgb(255, 80, 160), glow = true, sell = 12000 },
	{ key = "Ultra", noun = "Omni Ray", mult = 50, color = rgb(255, 255, 255), glow = true, sell = 0 }, -- raids only
}
Blasters.byRarity = {}
Blasters.RarityRank = {}
for i, r in Blasters.Rarities do
	r.rank = i
	Blasters.byRarity[r.key] = r
	Blasters.RarityRank[r.key] = i
end

Blasters.GradeColor = {
	plain = rgb(200, 200, 210),
	shiny = rgb(90, 220, 255),
	god = rgb(255, 215, 60),
}
Blasters.StatName = { dmg = "Damage", spd = "Speed", luck = "Luck", gem = "Gem Find" }
Blasters.StatEmoji = { dmg = "💥", spd = "⚡", luck = "🍀", gem = "💎" }

return Blasters

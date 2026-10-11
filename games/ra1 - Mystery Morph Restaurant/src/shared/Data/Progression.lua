-- Restaurant tiers (canon C6), player stats (C5) and the tutorial mutation parts (C13.6, QST_TUT_010).
local Progression = {}

Progression.Tiers = {
	{ id = "TIER_01", name = "Broken Burger Shack", cost = 0, level = 1, seats = 4, menu = 4, demand = 50 },
	{ id = "TIER_02", name = "Tiny Mutation Diner", cost = 1000, level = 5, seats = 6, menu = 5, demand = 65 },
}
Progression.TierById = {}
for i, t in Progression.Tiers do
	t.index = i
	Progression.TierById[t.id] = t
end

-- Order matches the canon table.
Progression.Stats = {
	{ code = "COOK_SPD", name = "Cooking Speed", cap = 150, blurb = "Stations and chopping run faster" },
	{ code = "COOK_QLT", name = "Cooking Quality", cap = 150, blurb = "Wider Perfect window, slower burning" },
	{ code = "STR", name = "Strength", cap = 150, blurb = "Hit harder in fights" },
	{ code = "DEF", name = "Defense", cap = 200, blurb = "Take less damage" },
	{ code = "REPAIR", name = "Repair Speed", cap = 150, blurb = "Fix broken stuff faster and cheaper" },
	{ code = "MOVE", name = "Movement Speed", cap = 100, blurb = "Walk faster" },
	{ code = "LUCK", name = "Luck", cap = 150, blurb = "Jackpot tips and rarer finds" },
	{ code = "CHARM", name = "Customer Charm", cap = 150, blurb = "More patient, calmer customers" },
	{ code = "EFFICIENCY", name = "Restaurant Efficiency", cap = 150, blurb = "Cheaper ingredients" },
}
Progression.StatByCode = {}
for _, s in Progression.Stats do
	Progression.StatByCode[s.code] = s
end
Progression.STAT_POINTS_PER_LEVEL = 2
Progression.MAX_ALLOCATED_PER_STAT = 50

-- [C13.8] Tutorial first mutation: one of these three, granted free at Lv1.
Progression.Mutations = {
	MUT_145 = {
		name = "Octopus Arm",
		slot = "ARM",
		rarity = "Uncommon",
		role = "Chef",
		stats = { COOK_SPD = 3, COOK_QLT = 1, EFFICIENCY = 3 },
		passive = "Extra Suckers: carry capacity +1",
		carryBonus = 1,
		ability = "ABL_012",
		color = Color3.fromRGB(150, 80, 200),
	},
	MUT_144 = {
		name = "Crab Claw Arm",
		slot = "ARM",
		rarity = "Uncommon",
		role = "Fighter",
		stats = { COOK_SPD = 1, STR = 3, EFFICIENCY = 3 },
		passive = "Pincer Toss: thrown objects knock back further",
		ability = "ABL_017",
		color = Color3.fromRGB(220, 60, 50),
	},
	MUT_153 = {
		name = "Wrench Claw Arm",
		slot = "ARM",
		rarity = "Rare",
		role = "Repair",
		stats = { STR = 3, REPAIR = 5, EFFICIENCY = 3 },
		passive = "Built-In Wrench: repair speed +10 %",
		repairBonus = 0.1,
		ability = "ABL_062",
		color = Color3.fromRGB(150, 156, 170),
	},
}
Progression.TutorialChoices = { "MUT_145", "MUT_144", "MUT_153" }
for id, m in Progression.Mutations do
	m.id = id
end

return table.freeze(Progression)

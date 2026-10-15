--[[
What lasts (master plan §6): levels and titles, achievements, the colours and flags the raft can wear, the research
milestones and the leaderboards' categories.
]]
local Progression = {}

-- Titles: earned by levels and achievements, shown over your head and on the boards.
Progression.TITLES = {
	{ key = "castaway", name = "Castaway", level = 1 },
	{ key = "builder", name = "Builder", level = 5 },
	{ key = "navigator", name = "Navigator", level = 10 },
	{ key = "captain", name = "Captain", level = 18 },
	{ key = "admiral", name = "Admiral", level = 30 },
	{ key = "legend", name = "Legend of the Trench", achievement = "leviathan_1" },
}

-- Colours for sails, banners and flags (the Decorative Workshop's dyes), and the deck's paint.
Progression.COLORS = {
	white = { name = "White", color = Color3.fromRGB(240, 236, 224), free = true },
	red = { name = "Red", color = Color3.fromRGB(200, 60, 50) },
	blue = { name = "Blue", color = Color3.fromRGB(60, 120, 210) },
	green = { name = "Green", color = Color3.fromRGB(70, 160, 90) },
	black = { name = "Black", color = Color3.fromRGB(40, 40, 46) },
	gold = { name = "Gold", color = Color3.fromRGB(240, 190, 60) },
}
Progression.DECKS = {
	natural = { name = "Natural", free = true },
	dark = { name = "Dark Stain" },
	white = { name = "Whitewash" },
}
-- Flag patterns (earned)
Progression.FLAGS = {
	{ key = "plain", name = "Plain", free = true },
	{ key = "anchor", name = "The Anchor", level = 8 },
	{ key = "wave", name = "The Wave", achievement = "voyages_10" },
	{ key = "sun", name = "The Sun", achievement = "islands_all" },
	{ key = "skull", name = "The Skull", achievement = "serpent_1" },
	{ key = "leviathan", name = "The Leviathan", achievement = "leviathan_1" },
}

-- Research milestones (the Research Station turns artifacts into points): each one unlocks a blueprint.
Progression.RESEARCH = {
	{ points = 40, unlock = { kind = "piece", key = "net" }, name = "Surface Net" },
	{ points = 120, unlock = { kind = "piece", key = "engine" }, name = "Engine" },
	{ points = 240, unlock = { kind = "recipe", key = "long_hook" }, name = "Long Hook" },
	{ points = 400, unlock = { kind = "recipe", key = "harpoon" }, name = "Harpoon" },
	{ points = 600, unlock = { kind = "piece", key = "salvage_net" }, name = "Salvage Net" },
	{ points = 850, unlock = { kind = "piece", key = "harpoon_turret" }, name = "Harpoon Turret" },
	{ points = 1200, unlock = { kind = "recipe", key = "salvage_claw" }, name = "Salvage Claw" },
	{ points = 1800, unlock = { kind = "recipe", key = "leviathan_harpoon" }, name = "Leviathan Harpoon" },
}

-- Achievements: stat = a profile stat and goal, or a flag set by the code.
Progression.ACHIEVEMENTS = {
	{
		key = "debris_100",
		name = "Beachcomber",
		icon = "🔗",
		desc = "Hook 100 pieces of debris.",
		stat = "debris",
		goal = 100,
	},
	{
		key = "debris_1000",
		name = "Salvager",
		icon = "⛓️",
		desc = "Hook 1,000 pieces of debris.",
		stat = "debris",
		goal = 1000,
	},
	{
		key = "tiles_10",
		name = "Room to Stand",
		icon = "🟫",
		desc = "A raft of 10 tiles.",
		stat = "tiles",
		goal = 10,
	},
	{ key = "tiles_30", name = "A Real Deck", icon = "🏠", desc = "A raft of 30 tiles.", stat = "tiles", goal = 30 },
	{
		key = "tiles_60",
		name = "Floating Fortress",
		icon = "🏰",
		desc = "A raft of 60 tiles.",
		stat = "tiles",
		goal = 60,
	},
	{ key = "tier_3", name = "Expedition Vessel", icon = "⛵", desc = "Reach raft tier 3.", stat = "tier", goal = 3 },
	{ key = "tier_5", name = "Fortress", icon = "🚢", desc = "Reach raft tier 5.", stat = "tier", goal = 5 },
	{ key = "tier_6", name = "Legendary", icon = "👑", desc = "Reach raft tier 6.", stat = "tier", goal = 6 },
	{ key = "voyages_1", name = "Land Ho", icon = "🏝️", desc = "Complete a voyage.", stat = "voyages", goal = 1 },
	{
		key = "voyages_10",
		name = "Old Salt",
		icon = "🧭",
		desc = "Complete 10 voyages.",
		stat = "voyages",
		goal = 10,
	},
	{
		key = "voyages_50",
		name = "The Endless Voyage",
		icon = "🌊",
		desc = "Complete 50 voyages.",
		stat = "voyages",
		goal = 50,
	},
	{ key = "islands_all", name = "Cartographer", icon = "🗺️", desc = "Visit every destination.", flag = true },
	{ key = "wreck_1", name = "Salvage Rights", icon = "⚓", desc = "Explore a wreck.", stat = "wrecks", goal = 1 },
	{ key = "fish_25", name = "Angler", icon = "🎣", desc = "Catch 25 fish.", stat = "fish", goal = 25 },
	{
		key = "fish_rare",
		name = "The One That Didn't Get Away",
		icon = "🐠",
		desc = "Catch a rare fish.",
		flag = true,
	},
	{ key = "koi", name = "Golden", icon = "🥇", desc = "Catch the Golden Koi.", flag = true },
	{ key = "crafted_25", name = "Handy", icon = "🛠️", desc = "Craft 25 things.", stat = "crafted", goal = 25 },
	{
		key = "storm_5",
		name = "Weathered",
		icon = "⛈️",
		desc = "Come through 5 storms.",
		stat = "storms",
		goal = 5,
	},
	{ key = "shark_10", name = "Shark Bait", icon = "🦈", desc = "Beat 10 sharks.", stat = "sharks", goal = 10 },
	{
		key = "serpent_1",
		name = "Serpent Slayer",
		icon = "🐍",
		desc = "Beat a sea serpent.",
		stat = "serpents",
		goal = 1,
	},
	{
		key = "guardian_1",
		name = "Tomb Raider",
		icon = "🗿",
		desc = "Beat the Ruin Guardian.",
		stat = "guardians",
		goal = 1,
	},
	{
		key = "leviathan_1",
		name = "Legend of the Trench",
		icon = "🐲",
		desc = "Beat the Leviathan.",
		stat = "leviathans",
		goal = 1,
	},
	{
		key = "puzzles_2",
		name = "Puzzler",
		icon = "💡",
		desc = "Solve both island puzzles.",
		stat = "puzzles",
		goal = 2,
	},
	{
		key = "research_1000",
		name = "Scholar of the Sea",
		icon = "📚",
		desc = "Earn 1,000 research points.",
		stat = "research",
		goal = 1000,
	},
	{
		key = "visitors_5",
		name = "Open Deck",
		icon = "🤝",
		desc = "Have 5 visitors aboard.",
		stat = "visitors",
		goal = 5,
	},
	{
		key = "journal_30",
		name = "Naturalist",
		icon = "📔",
		desc = "30 journal entries.",
		stat = "journal",
		goal = 30,
	},
}
Progression.achievementByKey = {}
for _, a in Progression.ACHIEVEMENTS do
	Progression.achievementByKey[a.key] = a
end

-- The leaderboards (friends first): record = a field of profile.records.
Progression.BOARDS = {
	{ key = "tier", name = "Raft Tier", icon = "⛵", record = "tier", unit = "" },
	{ key = "tiles", name = "Biggest Raft", icon = "🟫", record = "tiles", unit = " tiles" },
	{ key = "voyages", name = "Voyages", icon = "🧭", record = "voyages", unit = "" },
	{ key = "discoveries", name = "Discoveries", icon = "🔎", record = "discoveries", unit = "" },
	{ key = "leviathans", name = "Leviathans", icon = "🐲", record = "leviathans", unit = "" },
	{ key = "fish", name = "Fish Caught", icon = "🎣", record = "fish", unit = "" },
}
Progression.boardByKey = {}
for _, b in Progression.BOARDS do
	Progression.boardByKey[b.key] = b
end

return Progression

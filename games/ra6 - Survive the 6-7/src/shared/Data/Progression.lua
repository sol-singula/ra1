--[[
Permanent progression (master plan §9): four tracks that last between runs.

  Player level   XP from objectives, nights survived, discoveries and wins. Levels unlock choices (perks, starting
                 kits, titles), not bigger damage numbers.
  Mastery        using a weapon class unlocks an alternate move (level 3), a golden look (5) and a title (10).
  Bestiary and   monsters met, tells learned, golden variants, trophies; every item and finding type discovered;
  discoveries    Kermy's diary pages.
  Achievements   hard clears, speed, low damage, solo wins, team feats: titles and looks to show off.
]]
local Progression = {}

-- Perks: choose up to PERK_SLOTS(level). Small, choice-making bonuses (§9: no rewards that make new players
-- permanently weaker than veterans).
Progression.PERKS = {
	{ key = "lumberjack", name = "Lumberjack", icon = "🪓", level = 2, desc = "+30% wood from trees." },
	{
		key = "quick_hands",
		name = "Quick Hands",
		icon = "✋",
		level = 3,
		desc = "Build, craft and open things 30% faster.",
	},
	{
		key = "light_sleeper",
		name = "Light Sleeper",
		icon = "💤",
		level = 5,
		desc = "+8 seconds before you bleed out when downed.",
	},
	{
		key = "scavenger",
		name = "Scavenger",
		icon = "🔎",
		level = 7,
		desc = "15% chance of an extra item from every container.",
	},
	{ key = "marathon", name = "Marathon", icon = "🏃", level = 9, desc = "+20% stamina." },
	{
		key = "medic",
		name = "Medic",
		icon = "🩺",
		level = 12,
		desc = "Healing items heal 40% more; revive teammates 30% faster.",
	},
	{
		key = "trapper",
		name = "Trapper",
		icon = "🪤",
		level = 15,
		desc = "Traps get one extra use; start each run with a Snare.",
	},
	{
		key = "night_owl",
		name = "Night Owl",
		icon = "🦉",
		level = 18,
		desc = "See monsters' eyes glow from twice as far at night.",
	},
}
function Progression.perkSlots(level)
	if level >= 10 then
		return 2
	elseif level >= 2 then
		return 1
	end
	return 0
end

-- Starting kits: what you carry at the start of a run (pick one; more open with levels).
Progression.KITS = {
	{
		key = "woodsman",
		name = "Woodsman",
		icon = "🪓",
		level = 1,
		items = { { "rusty_axe", 1 }, { "torch", 1 } },
		desc = "A Rusty Axe and a Torch.",
	},
	{
		key = "hunter",
		name = "Hunter",
		icon = "🏹",
		level = 6,
		items = { { "rusty_axe", 1 }, { "short_bow", 1 }, { "arrows", 15 } },
		desc = "A Rusty Axe, a Short Bow and 15 arrows.",
	},
	{
		key = "medic",
		name = "Medic",
		icon = "🩹",
		level = 8,
		items = { { "rusty_axe", 1 }, { "bandage", 2 }, { "medkit", 1 } },
		desc = "A Rusty Axe, 2 bandages and a medkit.",
	},
	{
		key = "brawler",
		name = "Brawler",
		icon = "🏏",
		level = 11,
		items = { { "rusty_axe", 1 }, { "spiked_club", 1 } },
		desc = "A Rusty Axe and a Spiked Club.",
	},
	{
		key = "trapper",
		name = "Trapper",
		icon = "🪤",
		level = 14,
		items = { { "rusty_axe", 1 }, { "snare", 2 }, { "bear_trap", 1 } },
		desc = "A Rusty Axe, 2 snares and a bear trap.",
	},
	{
		key = "ranger",
		name = "Ranger",
		icon = "🧭",
		level = 20,
		items = { { "rusty_axe", 1 }, { "iron_spear", 1 }, { "lantern", 1 } },
		desc = "A Rusty Axe, an Iron Spear and a Lantern.",
	},
}

-- Mastery: per class, levels 1-10 (Constants.MASTERY_XP).
Progression.SPECIALS = {
	axe = {
		key = "whirl",
		name = "Whirl Chop",
		desc = "Spin with your axe and hit everything around you.",
		dmg = 1.2,
		radius = 9,
	},
	club = {
		key = "pound",
		name = "Ground Pound",
		desc = "Slam the ground: stagger and push back everything close.",
		dmg = 1,
		radius = 10,
	},
	spear = {
		key = "thrust",
		name = "Lunge Thrust",
		desc = "Dash forward and stab everything in a line.",
		dmg = 1.4,
		length = 14,
	},
	bow = { key = "volley", name = "Triple Shot", desc = "Shoot three arrows in a fan (uses one arrow).", arrows = 3 },
	trap = {
		key = "quickset",
		name = "Quick Set",
		desc = "Traps and throws are ready again twice as fast.",
		passive = true,
	},
	support = {
		key = "field_medic",
		name = "Field Medic",
		desc = "Your healing items also heal friends near you by half.",
		passive = true,
	},
}
Progression.MASTERY_REWARDS = {
	[3] = "special",
	[5] = "golden",
	[10] = "title",
}

-- Titles: shown under your name and on the leaderboards.
Progression.TITLES = {
	{ key = "camper", name = "Camper", from = "start" },
	{ key = "scout", name = "Scout", level = 5 },
	{ key = "ranger", name = "Ranger", level = 10 },
	{ key = "woodland_hero", name = "Woodland Hero", level = 20 },
	{ key = "forest_legend", name = "Forest Legend", level = 35 },
	{ key = "survivor", name = "Survivor", achievement = "survivor" },
	{ key = "hardened", name = "Hardened", achievement = "hard_win" },
	{ key = "nightmare", name = "Nightmare Walker", achievement = "nightmare_win" },
	{ key = "legend67", name = "Legend of 67", achievement = "sixseven_win" },
	{ key = "lone_wolf", name = "Lone Wolf", achievement = "solo_win" },
	{ key = "guardian", name = "Guardian Angel", achievement = "revive_50" },
	{ key = "kermy_kicker", name = "Kermy Kicker", achievement = "kermy_ko_10" },
	{ key = "diarist", name = "Kermy's Biographer", achievement = "pages_7" },
	{ key = "axe_master", name = "Axe Master", mastery = "axe" },
	{ key = "club_master", name = "Club Master", mastery = "club" },
	{ key = "spear_master", name = "Spear Master", mastery = "spear" },
	{ key = "bow_master", name = "Bow Master", mastery = "bow" },
	{ key = "trap_master", name = "Trap Master", mastery = "trap" },
	{ key = "support_master", name = "Field Medic", mastery = "support" },
}

-- Looks (§13: cosmetics are earned at launch; the shop comes after retention is proven). Built from parts and
-- worn on your own avatar (World/Looks).
Progression.LOOKS = {
	{ key = "ranger_hat", name = "Ranger Hat", icon = "🎩", slot = "hat", level = 4 },
	{ key = "leaf_crown", name = "Leaf Crown", icon = "🍃", slot = "hat", achievement = "first_night" },
	{ key = "kermy_hood", name = "Kermy Hood", icon = "🐸", slot = "hat", achievement = "pages_7" },
	{ key = "golden_67", name = "Golden 67 Chain", icon = "📿", slot = "neck", achievement = "survivor" },
	{ key = "camp_pack", name = "Camp Pack", icon = "🎒", slot = "back", level = 8 },
	{ key = "lantern_pack", name = "Lantern Pack", icon = "🏮", slot = "back", achievement = "camp_4" },
	{ key = "firefly_trail", name = "Firefly Trail", icon = "✨", slot = "aura", level = 15 },
	{ key = "crown_67", name = "Crown of the 67", icon = "👑", slot = "hat", achievement = "sixseven_win" },
}

-- Achievements: count ones finish when a stat reaches `goal`; the rest are earned by an event.
Progression.ACHIEVEMENTS = {
	{ key = "first_night", name = "First Night", icon = "🌙", desc = "Survive night 1." },
	{ key = "halfway", name = "Halfway There", icon = "🌗", desc = "Survive night 4." },
	{ key = "seventh_night", name = "The Seventh Night", icon = "🌕", desc = "Reach night 7." },
	{ key = "survivor", name = "Survive the 6-7", icon = "🏆", desc = "Beat Mega Kermy and win a run." },
	{ key = "hard_win", name = "Hard Case", icon = "💪", desc = "Win on Hard." },
	{ key = "nightmare_win", name = "Nightmare Fuel", icon = "😈", desc = "Win on Nightmare." },
	{ key = "sixseven_win", name = "Six-Seven Legend", icon = "👑", desc = "Win on Six-Seven." },
	{ key = "solo_win", name = "Lone Wolf", icon = "🐺", desc = "Win a run on your own." },
	{
		key = "no_one_left",
		name = "No One Left Behind",
		icon = "🤝",
		desc = "Win with nobody ending a night as a ghost.",
	},
	{ key = "untouched", name = "Untouched", icon = "✨", desc = "Win taking less than 250 damage." },
	{ key = "speedrunner", name = "Speedrunner", icon = "⏱️", desc = "Win in under 22 minutes." },
	{ key = "kermy_ko", name = "Kermy Down!", icon = "🐸", desc = "Knock Kermy out." },
	{
		key = "kermy_ko_10",
		name = "Kermy Kicker",
		icon = "🦶",
		desc = "Knock Kermy out 10 times.",
		stat = "kermyKO",
		goal = 10,
	},
	{
		key = "monsters_100",
		name = "Monster Masher",
		icon = "⚔️",
		desc = "Defeat 100 monsters.",
		stat = "monsters",
		goal = 100,
	},
	{
		key = "monsters_1000",
		name = "Forest Legend",
		icon = "🗡️",
		desc = "Defeat 1,000 monsters.",
		stat = "monsters",
		goal = 1000,
	},
	{
		key = "revive_10",
		name = "Helping Hand",
		icon = "🙌",
		desc = "Revive teammates 10 times.",
		stat = "rescues",
		goal = 10,
	},
	{
		key = "revive_50",
		name = "Guardian Angel",
		icon = "😇",
		desc = "Revive teammates 50 times.",
		stat = "rescues",
		goal = 50,
	},
	{ key = "dodge_100", name = "Slippery", icon = "💨", desc = "Dodge 100 attacks.", stat = "dodged", goal = 100 },
	{ key = "mimic_5", name = "Not Today, Mimic", icon = "📦", desc = "Defeat 5 mimics.", stat = "mimics", goal = 5 },
	{ key = "chop_500", name = "Lumberjack", icon = "🪵", desc = "Gather 500 wood.", stat = "wood", goal = 500 },
	{ key = "camp_4", name = "Stronghold", icon = "🏰", desc = "Upgrade the camp to The Stronghold." },
	{ key = "totem", name = "Totem Raiser", icon = "🗿", desc = "Raise the Totem of the Seventh Night." },
	{
		key = "treehugger",
		name = "Treehugger",
		icon = "🌲",
		desc = "Get Mega Kermy stuck in Ancient Pines 3 times in one fight.",
	},
	{ key = "goo_buster", name = "Goo Buster", icon = "🟢", desc = "Break a teammate out of a goo cocoon." },
	{ key = "sneaky", name = "Sneaky", icon = "🤫", desc = "Loot Kermy's hoard without waking him." },
	{ key = "legendary", name = "Legendary!", icon = "🌟", desc = "Find a legendary item." },
	{ key = "pages_7", name = "Dear Diary", icon = "📖", desc = "Find all 7 pages of Kermy's diary." },
	{ key = "bestiary", name = "Monster Expert", icon = "📚", desc = "Learn every tell of every monster." },
	{
		key = "collector",
		name = "Collector",
		icon = "🧺",
		desc = "Discover 30 different items.",
		stat = "itemsFound",
		goal = 30,
	},
	{ key = "explorer", name = "Explorer", icon = "🧭", desc = "Visit every kind of finding." },
	{ key = "mastery_10", name = "Master of One", icon = "🎖️", desc = "Reach mastery 10 with any weapon class." },
}

-- The friend leaderboards (§9): eight categories, friends first.
Progression.BOARDS = {
	{
		key = "difficulty",
		name = "Highest difficulty cleared",
		icon = "💀",
		record = "bestDifficulty",
		format = "difficulty",
	},
	{
		key = "fastest",
		name = "Fastest win",
		icon = "⏱️",
		record = "fastestWin",
		format = "time",
		ascending = true,
	},
	{ key = "nights", name = "Nights survived", icon = "🌙", record = "nights" },
	{ key = "discoveries", name = "Rarest discoveries", icon = "🔎", record = "discoveryScore" },
	{ key = "monsters", name = "Monsters defeated", icon = "⚔️", record = "monsters" },
	{ key = "rescues", name = "Teammates rescued", icon = "🤝", record = "rescues" },
	{ key = "mastery", name = "Weapon mastery", icon = "🎖️", record = "masteryTotal" },
	{ key = "achievements", name = "Achievements", icon = "🏆", record = "achievementCount" },
}

-- Lookups
local function index(list)
	local by = {}
	for i, x in list do
		x.order = i
		by[x.key] = x
	end
	return by
end
Progression.perkByKey = index(Progression.PERKS)
Progression.kitByKey = index(Progression.KITS)
Progression.titleByKey = index(Progression.TITLES)
Progression.lookByKey = index(Progression.LOOKS)
Progression.achievementByKey = index(Progression.ACHIEVEMENTS)
Progression.boardByKey = index(Progression.BOARDS)

return Progression

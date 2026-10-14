--[[
The monster roster (master plan §5 enemy behavior framework, §10 roster). Every monster has a readable silhouette,
a detection rule that makes sense, one distinctive behavior, an attack you can see coming and counter, a reason
to fight it (loot, a trophy, mastery), and a sound and animation of its own. MonsterService runs them; the
client draws them (MonsterController, World/Rigs); the bestiary shows what you've learned.

  hp, dmg, speed   base numbers (difficulty and the player count scale hp and dmg: Formulas)
  range            attack reach (studs)
  tell             seconds of wind-up you can see before the attack lands (§5: "an attack that can be anticipated")
  cost             threat points a night spends on one (Constants.NIGHT_BUDGET)
  size             small | medium | heavy (XP, knockback taken)
  nights           the first night it can come
  tips             what the bestiary teaches, one line per tell, unlocked as you learn them
]]
local Enemies = {}

Enemies.list = {
	{
		key = "kermy",
		name = "Kermy",
		icon = "🐸",
		role = "Signature pursuer",
		hp = 420,
		dmg = 30,
		speed = 19,
		range = 14,
		tell = 0.9,
		size = "heavy",
		cost = 0,
		nights = 1,
		trophy = "kermy_scrap",
		desc = "Six foot seven of swamp-green trouble in a jersey that's too small. He hunts whoever wanders off alone.",
		tips = {
			lunge = "He stops and yells SIX... SEVEN! with his hands going up and down. Then he lunges straight ahead: dodge sideways.",
			faceplant = "When his lunge misses he faceplants. Hit him while he's down.",
			retreat = "He 'runs away' when he's hurt, then looks back with a grin and charges. Don't chase him.",
			bush = "A shaking bush near you means he's taking a shortcut. He pops out of it.",
			bait = "Throw him a Smelly Sandwich and he stops to eat.",
		},
	},
	{
		key = "snapcap",
		name = "Snapcap",
		icon = "🍄",
		role = "Small nuisance",
		hp = 18,
		dmg = 6,
		speed = 14,
		range = 7,
		tell = 0.5,
		size = "small",
		cost = 1,
		nights = 1,
		trophy = "snapcap_cap",
		desc = "A hopping toadstool with far too many teeth. Comes in little gangs.",
		tips = {
			leap = "It squashes down before it jumps at you. Step aside.",
		},
	},
	{
		key = "grinwolf",
		name = "Grinwolf",
		icon = "🐺",
		role = "Pack hunter",
		hp = 45,
		dmg = 12,
		speed = 21,
		range = 7,
		tell = 0.6,
		size = "medium",
		cost = 3,
		nights = 2,
		trophy = "grinwolf_tooth",
		drops = { { "raw_meat", 1, 2, 0.7 } },
		desc = "Wolves with huge silly grins. They circle you and wait until you're busy.",
		tips = {
			dart = "One howls and its eyes flash red, then it darts in. Turn and face it.",
			busy = "They go for whoever is chopping or fighting something else.",
		},
	},
	{
		key = "pelter",
		name = "Pinecone Pelter",
		icon = "🐿️",
		role = "Ranged pest",
		hp = 28,
		dmg = 9,
		speed = 15,
		range = 30,
		tell = 0.7,
		size = "small",
		cost = 2.5,
		nights = 2,
		trophy = "pelter_crown",
		desc = "A squirrel-goblin in a pinecone helmet. Throws pinecones, then hides behind a tree.",
		tips = {
			lob = "A circle on the ground shows where the pinecone lands. Get out of it.",
			hide = "It hides behind trunks. Bows and spears reach it.",
		},
	},
	{
		key = "stumpy",
		name = "Stumpy",
		icon = "🪵",
		role = "Heavy brute",
		hp = 220,
		dmg = 26,
		speed = 11,
		range = 9,
		tell = 1.1,
		size = "heavy",
		cost = 7,
		nights = 3,
		trophy = "stumpy_bark",
		drops = { { "wood", 6, 10, 1 } },
		desc = "A walking tree stump with a grudge against walls.",
		tips = {
			slam = "It raises both arms and a red ring shows on the ground. Get out of the ring.",
			stagger = "A club or hammer hit during the wind-up staggers it.",
		},
	},
	{
		key = "mimic",
		name = "Mimic",
		icon = "📦",
		role = "Trickster",
		hp = 60,
		dmg = 10,
		speed = 18,
		range = 6,
		tell = 0.4,
		size = "medium",
		cost = 3,
		nights = 3,
		trophy = "mimic_tongue",
		desc = "A crate that isn't. Opens its lid to bite, then runs off on tiny legs with its loot inside.",
		tips = {
			breathe = "Real crates don't breathe. Watch the lid.",
			tired = "It gets tired after running. Catch it for great loot.",
		},
	},
	{
		key = "mega_kermy",
		name = "Mega Kermy",
		icon = "👹",
		role = "Final boss",
		hp = 3200,
		dmg = 40,
		speed = 16,
		range = 12,
		tell = 1.2,
		size = "boss",
		cost = 0,
		nights = 7,
		trophy = "golden_67",
		desc = "Kermy, but the size of a house. He comes for the camp on the seventh night.",
		tips = {
			charge = "A red line shows his charge. Stand in front of an Ancient Pine and dodge: he gets stuck in it.",
			dizzy = "Stuck and dizzy, the 67 on his back glows. Hit it hard.",
			slam = "When he jumps, rings of shockwave roll out where he lands. Jump over them.",
			grab = "He stuffs people into goo cocoons. Break your friends out.",
			tired = "After a few attacks he sits down, panting. Free hits.",
		},
	},
}

Enemies.byKey = {}
for i, e in Enemies.list do
	e.order = i
	Enemies.byKey[e.key] = e
end

-- Monsters that come at night (and their order of appearance), for the night planner.
Enemies.NIGHT = { "snapcap", "grinwolf", "pelter", "stumpy", "mimic" }
-- Elites: golden variants (§10: a higher-risk optional encounter)
Enemies.ELITE = { hp = 2.5, dmg = 1.25, speed = 1.1, cost = 2.5 }

function Enemies.get(key)
	return Enemies.byKey[key]
end

return Enemies

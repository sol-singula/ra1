-- Looks you unlock with coins (master plan §17, §18): dwarf armor, beards, monster skins, weapon looks, build
-- effects, emotes, win poses and castle flags. Looks only: nothing here makes anyone stronger, ever. Titles are
-- earned by playing, never bought.
local Looks = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Looks.slots = {
	{ key = "armor", name = "Dwarf Armor", icon = "🪖" },
	{ key = "beard", name = "Beard", icon = "🧔" },
	{ key = "skin", name = "Monster Skin", icon = "👹" },
	{ key = "weapon", name = "Weapon Look", icon = "🔨" },
	{ key = "buildFx", name = "Build Effect", icon = "✨" },
	{ key = "emote", name = "Emote", icon = "💃" },
	{ key = "pose", name = "Win Pose", icon = "🏆" },
	{ key = "flag", name = "Castle Flag", icon = "🚩" },
}

-- main/trim: the two colours a look paints; glow: a neon accent (or nil)
Looks.items = {
	-- dwarf armor (helmet, chest plate, shoulder pads)
	{ key = "iron", slot = "armor", name = "Iron", price = 0, main = rgb(160, 168, 186), trim = rgb(96, 102, 122) },
	{ key = "copper", slot = "armor", name = "Copper", price = 150, main = rgb(214, 128, 74), trim = rgb(140, 74, 42) },
	{ key = "rose", slot = "armor", name = "Rose", price = 250, main = rgb(255, 140, 186), trim = rgb(196, 70, 128) },
	{
		key = "royal",
		slot = "armor",
		name = "Royal Blue",
		price = 300,
		main = rgb(66, 120, 230),
		trim = rgb(255, 206, 70),
	},
	{ key = "golden", slot = "armor", name = "Gold", price = 400, main = rgb(255, 200, 60), trim = rgb(196, 130, 30) },
	{
		key = "emerald",
		slot = "armor",
		name = "Emerald",
		price = 600,
		main = rgb(46, 196, 110),
		trim = rgb(230, 236, 240),
	},
	{
		key = "obsidian",
		slot = "armor",
		name = "Obsidian",
		price = 900,
		main = rgb(46, 40, 60),
		trim = rgb(150, 90, 255),
		glow = rgb(170, 110, 255),
	},
	{
		key = "crystal",
		slot = "armor",
		name = "Crystal",
		price = 1200,
		main = rgb(190, 236, 255),
		trim = rgb(90, 200, 255),
		glow = rgb(110, 230, 255),
	},
	-- beards
	{ key = "brown", slot = "beard", name = "Brown", price = 0, main = rgb(122, 72, 40) },
	{ key = "ginger", slot = "beard", name = "Ginger", price = 100, main = rgb(226, 112, 40) },
	{ key = "black", slot = "beard", name = "Black", price = 100, main = rgb(44, 36, 34) },
	{ key = "gray", slot = "beard", name = "Gray", price = 100, main = rgb(168, 168, 172) },
	{ key = "snow", slot = "beard", name = "Snow", price = 150, main = rgb(244, 244, 248) },
	{
		key = "goldBraid",
		slot = "beard",
		name = "Gold Braids",
		price = 500,
		main = rgb(240, 186, 60),
		trim = rgb(255, 230, 120),
	},
	{ key = "rainbow", slot = "beard", name = "Rainbow", price = 800, main = rgb(255, 90, 140), rainbow = true },
	-- monster skins (each job keeps its own shape; the skin paints it)
	{ key = "classic", slot = "skin", name = "Classic", price = 0 },
	{ key = "frost", slot = "skin", name = "Frost", price = 300, main = rgb(140, 210, 255), trim = rgb(230, 248, 255) },
	{ key = "toxic", slot = "skin", name = "Toxic", price = 300, main = rgb(150, 230, 60), trim = rgb(120, 60, 190) },
	{
		key = "lava",
		slot = "skin",
		name = "Lava",
		price = 400,
		main = rgb(230, 80, 40),
		trim = rgb(60, 30, 30),
		glow = rgb(255, 150, 40),
	},
	{
		key = "ghost",
		slot = "skin",
		name = "Ghost",
		price = 500,
		main = rgb(220, 250, 245),
		trim = rgb(110, 220, 210),
		glow = rgb(140, 255, 230),
	},
	{ key = "candy", slot = "skin", name = "Candy", price = 600, main = rgb(255, 150, 210), trim = rgb(110, 220, 255) },
	{
		key = "shadow",
		slot = "skin",
		name = "Shadow",
		price = 700,
		main = rgb(50, 40, 70),
		trim = rgb(30, 24, 40),
		glow = rgb(255, 60, 90),
	},
	-- weapon looks (the head of your hammer, pick, axe, bow or staff)
	{ key = "steel", slot = "weapon", name = "Steel", price = 0, main = rgb(176, 182, 196) },
	{ key = "goldTool", slot = "weapon", name = "Gold", price = 300, main = rgb(255, 204, 60) },
	{
		key = "candyCane",
		slot = "weapon",
		name = "Candy Cane",
		price = 500,
		main = rgb(240, 60, 70),
		trim = rgb(250, 250, 250),
	},
	{
		key = "crystalTool",
		slot = "weapon",
		name = "Crystal",
		price = 600,
		main = rgb(120, 230, 255),
		glow = rgb(120, 230, 255),
	},
	{ key = "lavaTool", slot = "weapon", name = "Lava", price = 800, main = rgb(60, 30, 30), glow = rgb(255, 120, 40) },
	-- build effects (what flies off when your hammer hits)
	{ key = "dust", slot = "buildFx", name = "Dust", price = 0, main = rgb(232, 214, 180) },
	{ key = "hearts", slot = "buildFx", name = "Hearts", price = 300, main = rgb(255, 100, 150) },
	{ key = "sparkles", slot = "buildFx", name = "Gold Sparkles", price = 400, main = rgb(255, 214, 80) },
	{ key = "confetti", slot = "buildFx", name = "Confetti", price = 500, main = rgb(120, 200, 255), rainbow = true },
	{ key = "lightning", slot = "buildFx", name = "Lightning", price = 600, main = rgb(120, 230, 255) },
	-- emotes (the 💃 button)
	{ key = "wave", slot = "emote", name = "Wave", price = 0 },
	{ key = "cheer", slot = "emote", name = "Cheer", price = 150 },
	{ key = "laugh", slot = "emote", name = "Laugh", price = 200 },
	{ key = "flex", slot = "emote", name = "Flex", price = 250 },
	{ key = "dance", slot = "emote", name = "Dance", price = 300 },
	-- win poses (the results screen and the hangout podium)
	{ key = "hammerUp", slot = "pose", name = "Hammer Up", price = 0 },
	{ key = "bow", slot = "pose", name = "Take a Bow", price = 200 },
	{ key = "jump", slot = "pose", name = "Victory Jump", price = 300 },
	{ key = "bigRoar", slot = "pose", name = "Big Roar", price = 300 },
	-- castle flags (your Banners, and the flag over the gate when you built it)
	{
		key = "dragon",
		slot = "flag",
		name = "Red Dragon",
		price = 0,
		main = rgb(220, 50, 50),
		trim = rgb(255, 210, 70),
	},
	{
		key = "lion",
		slot = "flag",
		name = "Blue Lion",
		price = 200,
		main = rgb(50, 110, 220),
		trim = rgb(255, 255, 255),
	},
	{ key = "oak", slot = "flag", name = "Green Oak", price = 200, main = rgb(40, 170, 80), trim = rgb(250, 230, 160) },
	{
		key = "moon",
		slot = "flag",
		name = "Purple Moon",
		price = 300,
		main = rgb(130, 70, 210),
		trim = rgb(240, 240, 255),
	},
	{
		key = "crown",
		slot = "flag",
		name = "Gold Crown",
		price = 400,
		main = rgb(255, 196, 50),
		trim = rgb(150, 40, 40),
	},
	{ key = "rainbowFlag", slot = "flag", name = "Rainbow", price = 600, main = rgb(255, 90, 90), rainbow = true },
}

Looks.byKey = {}
Looks.bySlot = {}
Looks.default = {}
for i, item in Looks.items do
	item.order = i
	Looks.byKey[item.key] = item
	Looks.bySlot[item.slot] = Looks.bySlot[item.slot] or {}
	table.insert(Looks.bySlot[item.slot], item)
	if item.price == 0 and not Looks.default[item.slot] then
		Looks.default[item.slot] = item.key
	end
end

-- The rainbow cycle for rainbow looks.
Looks.RAINBOW = {
	rgb(255, 80, 80),
	rgb(255, 170, 60),
	rgb(255, 230, 70),
	rgb(90, 220, 110),
	rgb(80, 170, 255),
	rgb(170, 110, 255),
}

-- Titles: earned by playing (shown over your head and in the results).
Looks.titles = {
	{ key = "rookie", name = "Rookie", line = "Everyone starts here." },
	{ key = "wallMaster", name = "Wall Master", line = "Help build 100 walls.", stat = "walls", goal = 100 },
	{ key = "trapper", name = "Trapper", line = "Build 50 traps.", stat = "traps", goal = 50 },
	{ key = "rockEater", name = "Rock Eater", line = "Mine 2,000 materials.", stat = "mined", goal = 2000 },
	{ key = "medic", name = "Medic", line = "Heal 5,000 health.", stat = "healed", goal = 5000 },
	{ key = "monsterHunter", name = "Monster Hunter", line = "Beat 500 monsters.", stat = "beaten", goal = 500 },
	{
		key = "shrineKeeper",
		name = "Shrine Keeper",
		line = "Hold until the clock runs out 3 times.",
		stat = "dwarfWins",
		goal = 3,
	},
	{
		key = "lastDwarf",
		name = "Last Dwarf Standing",
		line = "Be the last dwarf alive.",
		stat = "lastDwarf",
		goal = 1,
	},
	{ key = "gateBreaker", name = "Gate Breaker", line = "Break 25 gates.", stat = "gates", goal = 25 },
	{ key = "shrineTaker", name = "Shrine Taker", line = "Take 20 shrines as a monster.", stat = "shrines", goal = 20 },
	{
		key = "patientZero",
		name = "Patient Zero",
		line = "Get turned by the plague 10 times.",
		stat = "turned",
		goal = 10,
	},
	{ key = "veteran", name = "Veteran", line = "Play 50 matches.", stat = "matches", goal = 50 },
}
Looks.titleByKey = {}
for i, t in Looks.titles do
	t.order = i
	Looks.titleByKey[t.key] = t
end

return Looks

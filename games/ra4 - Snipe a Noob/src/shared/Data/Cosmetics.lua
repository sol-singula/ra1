-- Everything you can wear: rifle skins, pop effects (what your target pops into), podium emotes, crosshairs and
-- kill-feed name colours. Nothing here changes how a rifle shoots.
--
-- Skins come from crates (odds shown), the Daily Shop (coins), the season pass and the daily TOP SNIPER prize.
-- A skin goes on any rifle. Skins are items with their own id, so they can be traded.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local C = {}

C.RARITIES = { "Common", "Rare", "Epic", "Legend", "Secret" }
C.RarityColor = {
	Common = rgb(190, 195, 205),
	Rare = rgb(70, 170, 255),
	Epic = rgb(190, 90, 255),
	Legend = rgb(255, 180, 40),
	Secret = rgb(255, 80, 160),
}
C.RarityRank = { Common = 1, Rare = 2, Epic = 3, Legend = 4, Secret = 5 }
-- Daily Shop price by rarity (coins)
C.ShopPrice = { Common = 500, Rare = 2000, Epic = 6000, Legend = 15000, Secret = 25000 }

-- Skins: body colour, accent colour, material, optional glow. source: "crate" (in crates and the shop),
-- "season" (season pass only), "prize" (daily TOP SNIPER only).
C.Skins = {
	{ id = "SAND", name = "Sand", rarity = "Common", body = rgb(210, 185, 140), accent = rgb(120, 100, 70) },
	{ id = "OLIVE", name = "Olive", rarity = "Common", body = rgb(110, 125, 70), accent = rgb(60, 60, 50) },
	{ id = "SNOW", name = "Snow", rarity = "Common", body = rgb(240, 245, 250), accent = rgb(150, 170, 190) },
	{ id = "NIGHT", name = "Night", rarity = "Common", body = rgb(35, 38, 55), accent = rgb(90, 95, 120) },
	{ id = "BRICK", name = "Brick", rarity = "Common", body = rgb(190, 80, 60), accent = rgb(230, 220, 200) },
	{ id = "MINT", name = "Mint", rarity = "Common", body = rgb(150, 230, 190), accent = rgb(60, 120, 100) },
	{ id = "BUBBLEGUM", name = "Bubblegum", rarity = "Rare", body = rgb(255, 140, 200), accent = rgb(255, 255, 255) },
	{ id = "OCEAN", name = "Ocean", rarity = "Rare", body = rgb(40, 120, 220), accent = rgb(120, 230, 255) },
	{ id = "LIME", name = "Lime Zap", rarity = "Rare", body = rgb(150, 230, 40), accent = rgb(30, 30, 40) },
	{ id = "TIGER", name = "Tiger", rarity = "Rare", body = rgb(255, 150, 30), accent = rgb(30, 30, 30) },
	{ id = "GRAPE", name = "Grape", rarity = "Rare", body = rgb(130, 70, 200), accent = rgb(230, 200, 255) },
	{ id = "CHERRY", name = "Cherry", rarity = "Rare", body = rgb(220, 30, 60), accent = rgb(60, 160, 60) },
	{
		id = "NEON",
		name = "Neon Rush",
		rarity = "Epic",
		body = rgb(30, 30, 45),
		accent = rgb(0, 255, 200),
		glow = true,
	},
	{
		id = "LAVA",
		name = "Lava",
		rarity = "Epic",
		body = rgb(60, 30, 25),
		accent = rgb(255, 110, 20),
		glow = true,
	},
	{
		id = "FROST",
		name = "Frost",
		rarity = "Epic",
		body = rgb(180, 230, 255),
		accent = rgb(255, 255, 255),
		material = "Glass",
	},
	{
		id = "CANDY",
		name = "Candy Cane",
		rarity = "Epic",
		body = rgb(255, 255, 255),
		accent = rgb(230, 30, 50),
	},
	{
		id = "TOXIC",
		name = "Toxic",
		rarity = "Epic",
		body = rgb(40, 50, 40),
		accent = rgb(150, 255, 60),
		glow = true,
	},
	{
		id = "GOLD",
		name = "Gold",
		rarity = "Legend",
		body = rgb(255, 200, 60),
		accent = rgb(255, 240, 170),
		material = "Foil",
	},
	{
		id = "DIAMOND",
		name = "Diamond",
		rarity = "Legend",
		body = rgb(170, 230, 255),
		accent = rgb(255, 255, 255),
		material = "Glass",
		glow = true,
	},
	{
		id = "DRAGON",
		name = "Dragon",
		rarity = "Legend",
		body = rgb(150, 20, 30),
		accent = rgb(255, 200, 40),
		glow = true,
	},
	{
		id = "GALAXY",
		name = "Galaxy",
		rarity = "Secret",
		body = rgb(40, 20, 90),
		accent = rgb(255, 100, 220),
		glow = true,
	},
	{
		id = "RAINBOW",
		name = "Rainbow",
		rarity = "Secret",
		body = rgb(255, 80, 80),
		accent = rgb(80, 200, 255),
		glow = true,
		rainbow = true,
	},
	-- season pass only
	{
		id = "S_COMET",
		name = "Comet",
		rarity = "Legend",
		body = rgb(30, 40, 80),
		accent = rgb(255, 230, 120),
		glow = true,
		source = "season",
	},
	{
		id = "S_ROYAL",
		name = "Royal",
		rarity = "Legend",
		body = rgb(90, 30, 140),
		accent = rgb(255, 215, 60),
		material = "Foil",
		source = "season",
	},
	{
		id = "S_ARCTIC",
		name = "Arctic Fox",
		rarity = "Epic",
		body = rgb(240, 250, 255),
		accent = rgb(80, 180, 255),
		source = "season",
	},
	{
		id = "S_JUNGLE",
		name = "Jungle",
		rarity = "Epic",
		body = rgb(40, 110, 50),
		accent = rgb(255, 210, 60),
		source = "season",
	},
	{
		id = "S_STORM",
		name = "Storm",
		rarity = "Legend",
		body = rgb(60, 70, 90),
		accent = rgb(120, 200, 255),
		glow = true,
		source = "season",
	},
	-- daily TOP SNIPER prize only (never sold)
	{
		id = "P_CROWN",
		name = "Champion",
		rarity = "Secret",
		body = rgb(255, 215, 60),
		accent = rgb(255, 80, 160),
		material = "Foil",
		glow = true,
		source = "prize",
	},
}
C.skinById = {}
for _, s in C.Skins do
	s.source = s.source or "crate"
	C.skinById[s.id] = s
end

-- Pop effects: what the player you pop bursts into.
C.PopEffects = {
	{
		id = "BRICKS",
		name = "Bricks",
		rarity = "Common",
		colors = { rgb(230, 90, 80), rgb(80, 150, 230), rgb(250, 200, 60) },
	},
	{
		id = "CONFETTI",
		name = "Confetti",
		rarity = "Rare",
		colors = { rgb(255, 95, 170), rgb(120, 220, 255), rgb(255, 230, 80), rgb(140, 240, 140) },
		small = true,
	},
	{
		id = "CANDY",
		name = "Candy",
		rarity = "Rare",
		colors = { rgb(255, 140, 200), rgb(255, 255, 255), rgb(255, 80, 120) },
		ball = true,
	},
	{
		id = "PIXELS",
		name = "Pixels",
		rarity = "Epic",
		colors = { rgb(0, 255, 200), rgb(0, 160, 255), rgb(255, 255, 255) },
		neon = true,
	},
	{
		id = "STARS",
		name = "Stars",
		rarity = "Epic",
		colors = { rgb(255, 230, 120), rgb(255, 255, 255) },
		neon = true,
		small = true,
	},
	{
		id = "BUBBLES",
		name = "Bubbles",
		rarity = "Epic",
		colors = { rgb(180, 230, 255), rgb(220, 250, 255) },
		ball = true,
		glass = true,
	},
	{
		id = "FIRE",
		name = "Fireworks",
		rarity = "Legend",
		colors = { rgb(255, 110, 20), rgb(255, 210, 60), rgb(255, 60, 60) },
		neon = true,
	},
	{ id = "GHOSTS", name = "Ghosts", rarity = "Legend", colors = { rgb(240, 245, 255) }, glass = true, rise = true },
}
C.effectById = {}
for _, e in C.PopEffects do
	C.effectById[e.id] = e
end

-- Emotes: what you do on the podium (Roblox's own R15 emote animations).
C.Emotes = {
	{ id = "WAVE", name = "Wave", rarity = "Common", anim = "rbxassetid://507770239" },
	{ id = "POINT", name = "Point", rarity = "Rare", anim = "rbxassetid://507770453" },
	{ id = "CHEER", name = "Cheer", rarity = "Rare", anim = "rbxassetid://507770677" },
	{ id = "LAUGH", name = "Laugh", rarity = "Epic", anim = "rbxassetid://507770818" },
	{ id = "DANCE", name = "Dance", rarity = "Epic", anim = "rbxassetid://507771019" },
	{ id = "DANCE2", name = "Groove", rarity = "Legend", anim = "rbxassetid://507776043" },
	{ id = "DANCE3", name = "Robot", rarity = "Legend", anim = "rbxassetid://507777268" },
}
C.emoteById = {}
for _, e in C.Emotes do
	C.emoteById[e.id] = e
end

-- Crosshairs: the shape and colour of your aim dot. Always in the Style shop.
C.Crosshairs = {
	{ id = "DOT", name = "Dot", price = 0, shape = "dot", color = rgb(255, 60, 60) },
	{ id = "CROSS", name = "Cross", price = 1000, shape = "cross", color = rgb(255, 255, 255) },
	{ id = "RING", name = "Ring", price = 2000, shape = "ring", color = rgb(120, 255, 140) },
	{ id = "PLUS", name = "Big Plus", price = 3000, shape = "plus", color = rgb(255, 220, 60) },
	{ id = "NEON", name = "Neon Dot", price = 5000, shape = "dot", color = rgb(0, 255, 220) },
	{ id = "PINK", name = "Pink Ring", price = 7500, shape = "ring", color = rgb(255, 95, 170) },
	{ id = "GOLD", name = "Gold Cross", price = 10000, shape = "cross", color = rgb(255, 200, 40) },
}
C.crosshairById = {}
for _, c in C.Crosshairs do
	C.crosshairById[c.id] = c
end

-- Kill-feed name colours. Always in the Style shop.
C.NameColors = {
	{ id = "WHITE", name = "White", price = 0, color = rgb(255, 255, 255) },
	{ id = "SKY", name = "Sky", price = 1000, color = rgb(120, 200, 255) },
	{ id = "LIME", name = "Lime", price = 1500, color = rgb(150, 240, 80) },
	{ id = "ORANGE", name = "Orange", price = 2500, color = rgb(255, 160, 40) },
	{ id = "PINK", name = "Pink", price = 4000, color = rgb(255, 110, 190) },
	{ id = "PURPLE", name = "Purple", price = 6000, color = rgb(190, 120, 255) },
	{ id = "GOLD", name = "Gold", price = 10000, color = rgb(255, 210, 60) },
}
C.nameColorById = {}
for _, c in C.NameColors do
	C.nameColorById[c.id] = c
end

-- Crates: what's inside, in percent by rarity (adds to 100). The skin of that rarity is picked evenly from the
-- crate skins. The Key Crate costs a key (keys are sold for Robux, so it is a paid random item: odds shown,
-- hidden for players whose account doesn't allow paid random items).
C.Crates = {
	{
		key = "COIN",
		name = "Coin Crate",
		emoji = "📦",
		coins = 2000,
		odds = { { "Common", 70 }, { "Rare", 24 }, { "Epic", 5 }, { "Legend", 1 } },
	},
	{
		key = "KEY",
		name = "Key Crate",
		emoji = "🎁",
		keys = 1,
		paid = true,
		odds = { { "Rare", 55 }, { "Epic", 33 }, { "Legend", 10 }, { "Secret", 2 } },
	},
}
C.crateByKey = {}
for _, c in C.Crates do
	C.crateByKey[c.key] = c
end

-- The crate skins of one rarity.
function C.crateSkins(rarity)
	local out = {}
	for _, s in C.Skins do
		if s.rarity == rarity and s.source == "crate" then
			table.insert(out, s)
		end
	end
	return out
end

return C

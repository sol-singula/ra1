-- Dragon skins: cosmetic paint for all of a player's dragons, bought in the Shop's Skins tab. A skin recolours
-- the wings, horns, spikes and belly; the body keeps its own colour so you can still tell which dragon it is
-- (and its rarity). Coin skins are bought with coins; Robux skins with the developer product named in
-- `product` (see Data/Shop.lua). Skins are owned forever and saved.
local Skins = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Skins.list = {
	{ key = "CLASSIC", name = "Classic", text = "Each dragon's own colours.", coins = 0, icon = "🐉" },
	{
		key = "MIDNIGHT",
		name = "Midnight",
		text = "Black wings, purple belly.",
		coins = 5000,
		icon = "🌙",
		wing = rgb(35, 32, 48),
		belly = rgb(150, 90, 230),
	},
	{
		key = "CANDY",
		name = "Candy",
		text = "Pink wings, mint belly.",
		coins = 25000,
		icon = "🍬",
		wing = rgb(255, 120, 200),
		belly = rgb(150, 245, 205),
	},
	{
		key = "OCEAN",
		name = "Ocean",
		text = "Deep blue wings, foam belly.",
		coins = 100000,
		icon = "🌊",
		wing = rgb(30, 110, 200),
		belly = rgb(215, 245, 255),
	},
	{
		key = "LAVA",
		name = "Lava",
		text = "Glowing lava wings!",
		product = "SKIN_LAVA",
		icon = "🌋",
		wing = rgb(255, 110, 30),
		wingMaterial = Enum.Material.Neon,
		belly = rgb(120, 25, 20),
	},
	{
		key = "ROYAL",
		name = "Royal Gold",
		text = "Shiny gold wings, pearl belly.",
		product = "SKIN_ROYAL",
		icon = "👑",
		wing = rgb(255, 195, 50),
		wingMaterial = Enum.Material.Foil,
		belly = rgb(250, 245, 235),
	},
	{
		key = "NEON",
		name = "Neon",
		text = "Glowing cyan wings, dark belly.",
		product = "SKIN_NEON",
		icon = "⚡",
		wing = rgb(60, 240, 255),
		wingMaterial = Enum.Material.Neon,
		belly = rgb(25, 25, 40),
	},
}

Skins.DEFAULT = "CLASSIC"
Skins.byKey = {}
Skins.byProduct = {}
for _, s in Skins.list do
	Skins.byKey[s.key] = s
	if s.product then
		Skins.byProduct[s.product] = s
	end
end

return Skins

-- Castle skins: Robux products that restyle your whole castle (walls, towers, roofs, trims), bought in the Shop's
-- CASTLES tab. Owned forever and saved; one is worn at a time (CastleSkinService, WorldBuilder.applyCastleSkin).
--   stone / dark      the walls and the darker stone (posts, plinths, gate)
--   accent            the coloured bands, roofs and banners (normally your base colour)
--   trim              the gold trims and flags
--   *Material         materials for those parts (nil keeps the castle's own)
--   rainbow           walls in rainbow bands instead of `stone`
--   fx                a particle effect drifting over the castle ("glitter", "stars", "snow", "embers", "leaves")
local CastleSkins = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

CastleSkins.list = {
	{
		key = "RAINBOW",
		name = "Rainbow Castle",
		text = "Every wall a different colour!",
		icon = "🌈",
		price = 249,
		rainbow = true,
		stone = rgb(255, 120, 120),
		dark = rgb(255, 255, 255),
		accent = rgb(255, 255, 255),
		trim = rgb(255, 230, 90),
		fx = "glitter",
	},
	{
		key = "GLITTER",
		name = "Glitter Castle",
		text = "Sparkly pink and pearl.",
		icon = "✨",
		price = 199,
		stone = rgb(255, 196, 228),
		dark = rgb(255, 240, 250),
		accent = rgb(255, 120, 200),
		trim = rgb(255, 255, 255),
		material = Enum.Material.Foil,
		accentMaterial = Enum.Material.Foil,
		fx = "glitter",
	},
	{
		key = "GOLD",
		name = "Golden Castle",
		text = "Solid gold, top to bottom.",
		icon = "👑",
		price = 299,
		stone = rgb(255, 200, 70),
		dark = rgb(220, 160, 40),
		accent = rgb(180, 30, 40),
		trim = rgb(255, 245, 200),
		material = Enum.Material.Foil,
		fx = "glitter",
	},
	{
		key = "ICE",
		name = "Ice Palace",
		text = "Frozen walls and falling snow.",
		icon = "❄️",
		price = 199,
		stone = rgb(200, 235, 255),
		dark = rgb(150, 205, 245),
		accent = rgb(90, 170, 255),
		trim = rgb(255, 255, 255),
		material = Enum.Material.Ice,
		accentMaterial = Enum.Material.Glass,
		fx = "snow",
	},
	{
		key = "LAVA",
		name = "Lava Fortress",
		text = "Black rock and glowing lava.",
		icon = "🌋",
		price = 199,
		stone = rgb(45, 40, 42),
		dark = rgb(25, 22, 24),
		accent = rgb(255, 100, 20),
		trim = rgb(255, 170, 40),
		material = Enum.Material.Basalt,
		accentMaterial = Enum.Material.Neon,
		fx = "embers",
	},
	{
		key = "CANDY",
		name = "Candy Castle",
		text = "Pastel pink and mint, like sweets.",
		icon = "🍭",
		price = 149,
		stone = rgb(255, 205, 225),
		dark = rgb(170, 240, 210),
		accent = rgb(255, 130, 180),
		trim = rgb(255, 250, 200),
		material = Enum.Material.SmoothPlastic,
		accentMaterial = Enum.Material.SmoothPlastic,
		fx = "glitter",
	},
	{
		key = "GALAXY",
		name = "Galaxy Castle",
		text = "Deep space with glowing stars.",
		icon = "🌌",
		price = 249,
		stone = rgb(30, 26, 70),
		dark = rgb(15, 12, 40),
		accent = rgb(170, 90, 255),
		trim = rgb(120, 230, 255),
		material = Enum.Material.SmoothPlastic,
		accentMaterial = Enum.Material.Neon,
		fx = "stars",
	},
	{
		key = "JUNGLE",
		name = "Jungle Temple",
		text = "Mossy stone and vines.",
		icon = "🌿",
		price = 149,
		stone = rgb(120, 140, 100),
		dark = rgb(80, 100, 64),
		accent = rgb(60, 160, 70),
		trim = rgb(230, 200, 90),
		material = Enum.Material.Slate,
		accentMaterial = Enum.Material.Grass,
		fx = "leaves",
	},
	{
		key = "CHOCOLATE",
		name = "Chocolate Castle",
		text = "Milk chocolate with pistachio and gold.",
		icon = "🍫",
		price = 199,
		stone = rgb(110, 66, 38),
		dark = rgb(70, 40, 22),
		accent = rgb(168, 204, 96),
		trim = rgb(255, 205, 80),
		material = Enum.Material.SmoothPlastic,
		fx = "glitter",
	},
	{
		key = "NEON",
		name = "Neon Night",
		text = "Dark walls with bright neon lines.",
		icon = "⚡",
		price = 199,
		stone = rgb(30, 32, 40),
		dark = rgb(18, 18, 24),
		accent = rgb(0, 240, 255),
		trim = rgb(255, 60, 220),
		material = Enum.Material.SmoothPlastic,
		accentMaterial = Enum.Material.Neon,
		fx = "stars",
	},
}

CastleSkins.byKey = {}
CastleSkins.byProduct = {}
for _, s in CastleSkins.list do
	s.product = "CASTLE_" .. s.key
	CastleSkins.byKey[s.key] = s
	CastleSkins.byProduct[s.product] = s
end

return CastleSkins

--[[
Every cosmetic in the game, wherever it comes from, and what it looks like. All cosmetic: nothing here changes a
shot, a hit, health, speed or building (master plan §1: fair competition, nothing paid adds combat power).

  kind     trail (your arrows) | skin (your bow) | sword (your blade in the CHARGE) | effect (what a kill of yours
           looks like) | banner (the emblem on your team banners) | title (under your name)
  rarity   common | rare | epic | legendary (the shop's price, the card's colour band)
  source   how it's had:
             ladder       the 100-win ladder (Data/Ladder): win N
             shop         bought with Shards (◆) while it's in the shop's rotation (Data/Shop)
             pass         the season's Turf Pass (Data/Season), free or premium track; never sold again
             goal         earned only: a stat or a feat (Data/Achievements); never sold
             vip / mvp    earned only: comes with VIP or MVP status (Data/Achievements); never sold
             extra        given for something you did (Data/Extras: answering, inviting a friend)
             starter      the Starter Pack (once, Robux)
             robux        Robux only, yours for good (Data/Shop.PREMIUM: a developer product each; it.robux the price)
  look     what the client draws (LooksController, ArrowController, WeaponController, BuildService):
             trail   lines = { { x, y, width, color } } beside the tracer, a ribbon, and how they're drawn (dash,
                     dots, helix, bolt, fire, ghost... see TRAIL below), length (x the tracer)
             skin    grip, limbs (colour tokens), material
             sword   shape (Shared/SwordSkins draws it: sword, katana, gladius, cleaver, pixel, saber, scythe), the
                     colour tokens of its parts (edge, bevel, spine, guard, grip, gem), material, anim, particles,
                     sticker; trail: the token its slash streak is drawn in
             effect  shape (one of FX/KillEffects.SHAPES), color, count (bursts, trim: the shatter's variants)
             banner  emblem (one character)
             title   text
           colour tokens: "team" (your team's colour), "light" (a lighter shade of it), "white", "ink" (black), and
           the bright ones: gold, yellow, pink, lava, ice, electric, galaxy, candy, rainbow (moving through hues)

  Cosmetics.get(key)         the item (ladder, extras and season items are resolved here too), or nil
  Cosmetics.list             every fixed item (not the generated season ones)
]]
local Constants = require(script.Parent.Parent.Constants)
local Ladder = require(script.Parent.Ladder)
local Extras = require(script.Parent.Extras)

local Cosmetics = {}

Cosmetics.KINDS = { "trail", "skin", "sword", "effect", "banner", "title" }
Cosmetics.KIND_NAME = {
	trail = "TRAIL",
	skin = "BOW",
	sword = "SWORD SKIN",
	effect = "KILL EFFECT",
	banner = "BANNER",
	title = "TITLE",
}
Cosmetics.RARITIES = { "common", "rare", "epic", "legendary" }

-- Looks, by name, so the ladder, the shop and the pass can share them -----------------------------------------
-- Trails (ArrowController draws them; FX/Flair the bits that fall off): each its own shape, not just a colour.
--   lines    { { x, y, width, token } } beside the tracer       ribbon  { w, token, life, taper?, alpha?, twist? }
--   dash     the lines in pieces: dots (balls), bars (across),   a soft Trail off the arrow (life: seconds, so its
--            crystal (diamonds); march (studs/s they slide)      length); twist: a flat ribbon that turns over
--   helix    the lines wound round the tracer (turns)           spin    the lines turning round it (rate)
--   converge the lines meeting at the tip                       wobble  the lines waving    flicker  blinking
--   jitter   shaking; rgb: a glitch's colour split, snapping    pulse   widths throbbing (rate)
--   bolt     a lightning bolt re-jagged along the tracer         fire    flames off the head  wisp  ghostly smoke
--   ghost    afterimages of the shaft (ghostColor, wave)         rings   rings of energy every so often (seconds)
--   light    a glow on the arrow (a token)                       particles  what falls off it (FX/Flair.drop)
local TRAIL = {
	-- the ladder: simple, each still its own
	["White Line"] = { lines = { { 0.2, 0.06, 0.06, "white" } }, ribbon = { 0.16, "white", 0.14 } },
	["Dotted"] = { dash = true, dots = true, march = 7, lines = { { 0, 0.16, 0.13, "white" } } },
	["Long Streak"] = { length = 1.8, ribbon = { 0.12, "light", 0.5, 0 } },
	["Twin Lines"] = { converge = true, lines = { { 0.3, 0, 0.07, "team" }, { -0.3, 0, 0.07, "team" } } },
	["Spiral"] = { helix = 1.5, spin = 10, lines = { { 0.26, 0, 0.07, "white" }, { -0.26, 0, 0.07, "light" } } },
	["Comet"] = {
		fire = true,
		lines = { { 0, 0, 0.16, "lava" } },
		ribbon = { 0.75, "lava", 0.3, 0 },
		length = 0.6,
		light = "lava",
		particles = "embers",
	},
	["Glitch"] = { rgb = true, flicker = true, lines = { { 0.1, 0.06, 0.07, "candy" }, { -0.1, -0.06, 0.07, "ice" } } },
	["Shards"] = {
		dash = true,
		crystal = true,
		lines = { { 0.18, 0, 0.14, "ice" }, { -0.18, 0, 0.14, "white" } },
		particles = "shards",
	},
	["Ribbon"] = { ribbon = { 0.7, "team", 0.4, 0.4, 0.15, true } },
	["Neon"] = { lines = { { 0, 0, 0.05, "white" } }, length = 1.3, pulse = 10, ribbon = { 0.3, "team", 0.12, 0 } },
	-- the extras
	["Thank-You Trail"] = { lines = { { 0.2, 0.06, 0.06, "white" } }, particles = "glints" },
	["Buddy Trail"] = { helix = 0.75, spin = 4, lines = { { 0.22, 0, 0.07, "white" }, { -0.22, 0, 0.07, "yellow" } } },
	-- shop
	["Barcode"] = { dash = true, bars = true, lines = { { 0, 0, 0.05, "ink" } } },
	["Static Line"] = {
		jitter = true,
		flicker = true,
		lines = { { 0, 0.14, 0.05, "white" }, { 0, 0.14, 0.02, "ink" } },
	},
	["Double Helix"] = {
		helix = 2.5,
		spin = 6,
		dots = true,
		lines = { { 0.32, 0, 0.12, "team" }, { -0.32, 0, 0.12, "white" } },
	},
	["Inkline"] = { lines = { { 0, 0.1, 0.08, "ink" } }, ribbon = { 0.3, "ink", 0.25, 0.2, 0.3 }, particles = "ink" },
	["Tripwire"] = {
		spin = 3,
		lines = { { 0.24, -0.12, 0.04, "white" }, { -0.24, -0.12, 0.04, "white" }, { 0, 0.26, 0.04, "candy" } },
	},
	["Echo"] = { ghost = 3, ghostColor = "ice", wave = true, wisp = true },
	["Overcharge"] = {
		lines = { { 0, 0, 0.3, "light" }, { 0, 0, 0.04, "white" } },
		length = 1.5,
		pulse = 14,
		rings = 0.09,
		light = "team",
		particles = "sparks",
	},
	-- the big ones (anim: drawn alive by ArrowController; particles: what falls off the arrow as it flies)
	["Rainbow Road"] = {
		anim = "rainbow",
		lines = { { 0, 0, 0.18, "rainbow" } },
		ribbon = { 1, "rainbow", 0.45, 0.3 },
		length = 1.4,
		light = "rainbow",
		particles = "sparkles",
	},
	["Feather Trail"] = {
		lines = { { 0, 0, 0.05, "white" } },
		ribbon = { 0.4, "white", 0.3, 0.2, 0.6 },
		particles = "feathers",
	},
	["Bubble Trail"] = { wobble = true, lines = { { 0, 0, 0.06, "ice" } }, particles = "bubbles" },
	["Pixel Rain"] = { dash = true, lines = { { 0, 0, 0.14, "rainbow" } }, particles = "pixels" },
	["Thunder Trail"] = {
		anim = "electric",
		bolt = true,
		lines = { { 0, 0, 0.06, "electric" } },
		ribbon = { 0.5, "electric", 0.18, 0 },
		length = 1.6,
		light = "electric",
		particles = "sparks",
	},
	["Hearts"] = {
		pulse = 6,
		lines = { { 0, 0, 0.06, "pink" } },
		ribbon = { 0.35, "pink", 0.25 },
		particles = "hearts",
	},
	-- goals and status
	["Crosshair Line"] = { dash = true, march = 4, lines = { { 0, 0.2, 0.05, "ink" }, { 0, -0.2, 0.05, "ink" } } },
	["Long Shot"] = { length = 2.4, lines = { { 0, 0, 0.03, "white" } }, ribbon = { 0.07, "white", 0.8, 0.5, 0.4 } },
	["Afterimage"] = { ghost = 3, ghostColor = "ink", lines = { { 0, 0.12, 0.04, "ink" } }, particles = "glints" },
}
local SKIN = {
	["Matte Black"] = { grip = "ink", limbs = "ink", material = "SmoothPlastic" },
	["Chalk"] = { grip = "white", limbs = "white", material = "Sand" },
	["Glass"] = { grip = "team", limbs = "white", material = "Glass" },
	["Chrome"] = { grip = "ink", limbs = "white", material = "Metal" },
	["Marble"] = { grip = "white", limbs = "white", material = "Marble" },
	["Gold Edge"] = { grip = "ink", limbs = "gold", material = "Metal", anim = "pulse" },
	["Carbon"] = { grip = "ink", limbs = "ink", material = "Fabric" },
	["Frosted"] = { grip = "light", limbs = "white", material = "Ice", anim = "frost", particles = "snow" },
	["Obsidian"] = { grip = "ink", limbs = "ink", material = "Glass" },
	["Prism"] = { grip = "team", limbs = "rainbow", material = "Neon", anim = "rainbow" },
	-- shop
	["Team Neon"] = { grip = "team", limbs = "team", material = "Neon", anim = "pulse" },
	["Porcelain"] = { grip = "white", limbs = "light", material = "SmoothPlastic" },
	["Graphite"] = { grip = "ink", limbs = "light", material = "Slate" },
	["Hologram"] = { grip = "light", limbs = "light", material = "ForceField", anim = "sparkle" },
	-- the big ones (anim: drawn alive by WeaponController: rainbow colour cycle, pulse, sparkle, embers, electric,
	-- frost; particles: what comes off the bow while you hold it)
	["Rainbow Cycle"] = { grip = "rainbow", limbs = "rainbow", material = "Neon", anim = "rainbow" },
	["Lava"] = { grip = "ink", limbs = "lava", material = "Neon", anim = "pulse", particles = "embers" },
	["Galaxy"] = { grip = "galaxy", limbs = "galaxy", material = "Glass", anim = "sparkle", particles = "sparkles" },
	["Candy Cane"] = { grip = "white", limbs = "candy", material = "SmoothPlastic", anim = "stripes" },
	["Frostbite"] = { grip = "light", limbs = "ice", material = "Ice", anim = "frost", particles = "snow" },
	["Storm Caller"] = { grip = "ink", limbs = "electric", material = "Neon", anim = "electric", particles = "sparks" },
	["Golden Dragon"] = {
		grip = "gold",
		limbs = "gold",
		material = "Metal",
		anim = "pulse",
		particles = "embers",
		wings = true,
	},
	-- goals and status
	["Bulldozer"] = { grip = "ink", limbs = "white", material = "DiamondPlate" },
	["Inkwell"] = { grip = "ink", limbs = "ink", material = "Neon" },
}
-- Sword skins (Shared/SwordSkins builds the blade, FX/Flair brings it alive): each its own shape and colours, plain
-- box parts like the rest of the game. Tokens: edge (the blade), bevel (its bright line), spine (the line down the
-- middle), guard, grip, gem; trail: the colour its slash streak is drawn in (the edge's when unset)
--   anim      frost (see-through ice, cold mist) | ember (a lava core, embers) | neon (the edge line throbbing) |
--             rainbow | electric (arcs crackling down the blade) | pixel (its blocks cycling) | shadow (dark smoke) |
--             pulse (the edge line throbbing)
--   sticker   a character on the guard, both faces (the Doge Blade)
local STEEL, BEVEL, FULLER, GUARD =
	Color3.fromRGB(214, 218, 225),
	Color3.fromRGB(250, 251, 253),
	Color3.fromRGB(150, 155, 164),
	Color3.fromRGB(118, 122, 132)
local SWORD = {
	-- (the plain blade everyone starts with: Shared/SwordSkins.PLAIN is this)
	["Steel"] = {
		shape = "sword",
		edge = STEEL,
		bevel = BEVEL,
		spine = FULLER,
		guard = GUARD,
		grip = "team",
		gem = "team",
	},
	-- shop
	["Chalk Blade"] = {
		shape = "sword",
		edge = "white",
		bevel = "white",
		spine = "ink",
		guard = "ink",
		grip = "ink",
		gem = "white",
		material = "Sand",
	},
	["Inkblade"] = {
		shape = "sword",
		edge = "ink",
		bevel = "white",
		spine = "ink",
		guard = "ink",
		grip = "team",
		gem = "white",
	},
	["Pixel Sword"] = {
		shape = "pixel",
		edge = "team",
		bevel = "white",
		guard = "ink",
		grip = "ink",
		gem = "yellow",
		anim = "pixel",
	},
	["Frost Edge"] = {
		shape = "sword",
		edge = "ice",
		bevel = "white",
		spine = "ice",
		guard = "white",
		grip = "light",
		gem = "ice",
		material = "Ice",
		anim = "frost",
		particles = "snow",
		trail = "ice",
	},
	["Golden Gladius"] = {
		shape = "gladius",
		edge = "gold",
		bevel = "yellow",
		spine = "gold",
		guard = "gold",
		grip = "ink",
		gem = "candy",
		particles = "glints",
		trail = "gold",
	},
	["Ember Blade"] = {
		shape = "sword",
		edge = "ink",
		bevel = "lava",
		spine = "lava",
		guard = "ink",
		grip = "ink",
		gem = "lava",
		anim = "ember",
		particles = "embers",
		trail = "lava",
	},
	["Neon Katana"] = {
		shape = "katana",
		edge = "ink",
		bevel = "team",
		guard = "ink",
		grip = "ink",
		gem = "team",
		anim = "neon",
		trail = "light",
	},
	["Obsidian Cleaver"] = {
		shape = "cleaver",
		edge = "ink",
		bevel = "candy",
		spine = "candy",
		guard = "ink",
		grip = "ink",
		gem = "candy",
		material = "Glass",
		anim = "pulse",
		trail = "candy",
	},
	["Rainbow Saber"] = {
		shape = "saber",
		edge = "rainbow",
		bevel = "white",
		guard = "ink",
		grip = "ink",
		gem = "rainbow",
		anim = "rainbow",
		particles = "sparkles",
		trail = "rainbow",
	},
	-- Robux only
	["Lightning Fang"] = {
		shape = "katana",
		edge = "electric",
		bevel = "white",
		guard = "ink",
		grip = "ink",
		gem = "electric",
		anim = "electric",
		particles = "sparks",
		trail = "electric",
	},
	["Doge Blade"] = {
		shape = "gladius",
		edge = "gold",
		bevel = "yellow",
		spine = "gold",
		guard = "yellow",
		grip = "ink",
		gem = "gold",
		anim = "pulse",
		particles = "glints",
		sticker = "🐕",
		trail = "gold",
	},
	["Shadow Scythe"] = {
		shape = "scythe",
		edge = "ink",
		bevel = "galaxy",
		spine = "galaxy",
		guard = "ink",
		grip = "ink",
		gem = "galaxy",
		anim = "shadow",
		particles = "wisp",
		trail = "galaxy",
	},
}
Cosmetics.SWORD = SWORD

-- Kill effects (FX/KillEffects): each shape is its own little film; Triple Shatter and VIP Shatter are the
-- shatter broken three times (bursts) and in black glass and gold (trim)
local EFFECT = {
	["Shatter"] = { shape = "shards", color = "white", count = 10 },
	["Poof"] = { shape = "smoke", color = "light", count = 8 },
	["Cubes"] = { shape = "cubes", color = "team", count = 12 },
	["Ring"] = { shape = "ring", color = "white", count = 12 },
	["Fold"] = { shape = "fold", color = "ink", count = 9 },
	["Static"] = { shape = "static", color = "white", count = 16 },
	["Pixels"] = { shape = "pixels", color = "team", count = 16 },
	["Spark"] = { shape = "spark", color = "light", count = 14 },
	["Slice"] = { shape = "slice", color = "ink", count = 8 },
	["Supernova"] = { shape = "nova", color = "team", count = 20 },
	-- shop
	["Confetti"] = { shape = "confetti", color = "white", count = 24 },
	["Ink Splash"] = { shape = "ink", color = "ink", count = 14 },
	["Double Ring"] = { shape = "orbit", color = "light", count = 18 },
	["Ascend"] = { shape = "rise", color = "white", count = 10 },
	-- the big ones: each is its own animation (KillFxController; shown slowed down in the victim's kill cam)
	["Feather Burst"] = { shape = "feathers", color = "white", count = 26 },
	["Rainbow Sparkle"] = { shape = "sparkles", color = "rainbow", count = 40 },
	["Block Party"] = { shape = "blocks", color = "rainbow", count = 24 },
	["Firework"] = { shape = "firework", color = "rainbow", count = 36 },
	["Bubble Pop"] = { shape = "bubbles", color = "light", count = 22 },
	["Chicken"] = { shape = "chicken", color = "white", count = 12, funny = true }, -- they turn into a chicken and run
	["Rubber Duck"] = { shape = "duck", color = "yellow", count = 10, funny = true }, -- a giant duck pops out, squeak
	["Balloon Ride"] = { shape = "balloons", color = "rainbow", count = 8, funny = true }, -- floated away on balloons
	["Banana Slip"] = { shape = "banana", color = "yellow", count = 6, funny = true }, -- slip, spin, splat
	["Lightning Strike"] = { shape = "lightning", color = "electric", count = 16 },
	["Much Wow"] = { shape = "doge", color = "gold", count = 6, funny = true }, -- a shiba pops up: "wow" "such kill"
	["Web Slinger"] = { shape = "web", color = "white", count = 12 }, -- webbed up and yanked away
	["OOF"] = { shape = "oof", color = "yellow", count = 8, funny = true }, -- a giant bouncing OOF
	["Bonk"] = { shape = "bonk", color = "white", count = 6, funny = true }, -- a giant cartoon mallet: BONK
	["Dance Off"] = { shape = "dance", color = "rainbow", count = 20, funny = true }, -- a disco floor, they dance out
	["Black Hole"] = { shape = "blackhole", color = "ink", count = 30 },
	["Golden Gate"] = { shape = "heaven", color = "gold", count = 24 }, -- golden light, wings, up they go
	-- goals and status
	["Centurion"] = { shape = "spears", color = "ink", count = 24 },
	["Triple Shatter"] = { shape = "shards", color = "team", count = 24, bursts = 3 },
	["VIP Shatter"] = { shape = "shards", color = "ink", count = 18, trim = "gold" },
	["Spotlight"] = { shape = "spotlight", color = "white", count = 12 },
}
local EMBLEM = {
	Chevron = "⌃",
	Star = "★",
	Arrow = "➤",
	Crown = "♛",
	Bolt = "ϟ",
	Eye = "◉",
	Wing = "≫",
	Skull = "☠",
	Sun = "☀",
	Infinity = "∞",
	-- shop, goals, starter
	Diamond = "◆",
	Target = "◎",
	Spade = "♠",
	Anchor = "⚓",
	Blueprint = "▦",
	Founder = "✦",
	-- the big ones (drawn alive: anim spin | pulse | rainbow | flame | sparkle)
	Flame = "🔥",
	Rainbow = "🌈",
	Lightning = "⚡",
	Doge = "🐕",
	Chicken = "🐔",
	Skulls = "💀",
	Galaxy = "🌌",
	Crown2 = "👑",
}
local BANNER_ANIM = {
	Star = "sparkle",
	Crown = "sparkle",
	Bolt = "electric",
	Sun = "spin",
	Skull = "pulse",
	Infinity = "rainbow",
	Diamond = "sparkle",
	Founder = "sparkle",
	Flame = "flame",
	Rainbow = "rainbow",
	Lightning = "electric",
	Doge = "pulse",
	Chicken = "bounce",
	Skulls = "spin",
	Galaxy = "sparkle",
	Crown2 = "sparkle",
}

local function look(kind, name)
	local base = string.gsub(name, " I+$", "")
	if kind == "trail" then
		return TRAIL[base] or TRAIL["White Line"]
	elseif kind == "skin" then
		return SKIN[base] or SKIN["Matte Black"]
	elseif kind == "sword" then
		return SWORD[base] or SWORD["Steel"]
	elseif kind == "effect" then
		return EFFECT[base] or EFFECT["Shatter"]
	elseif kind == "banner" then
		return { emblem = EMBLEM[base] or "★", anim = BANNER_ANIM[base] }
	end
	return { text = name }
end
Cosmetics.look = look

-- The fixed items ---------------------------------------------------------------------------------------------
local function item(key, kind, name, rarity, source, extra)
	local it = { key = key, kind = kind, name = name, rarity = rarity, source = source, look = look(kind, name) }
	for k, v in extra or {} do
		it[k] = v
	end
	return it
end

Cosmetics.list = {
	-- the shop's pool (Data/Shop rotates through these)
	item("shop_barcode", "trail", "Barcode", "common", "shop"),
	item("shop_inkline", "trail", "Inkline", "common", "shop"),
	item("shop_static", "trail", "Static Line", "rare", "shop"),
	item("shop_tripwire", "trail", "Tripwire", "rare", "shop"),
	item("shop_helix", "trail", "Double Helix", "epic", "shop"),
	item("shop_echo", "trail", "Echo", "epic", "shop"),
	item("shop_overcharge", "trail", "Overcharge", "legendary", "shop"),
	item("shop_porcelain", "skin", "Porcelain", "common", "shop"),
	item("shop_graphite", "skin", "Graphite", "rare", "shop"),
	item("shop_teamneon", "skin", "Team Neon", "epic", "shop"),
	item("shop_hologram", "skin", "Hologram", "legendary", "shop"),
	item("shop_confetti", "effect", "Confetti", "common", "shop"),
	item("shop_ink", "effect", "Ink Splash", "rare", "shop"),
	item("shop_doublering", "effect", "Double Ring", "epic", "shop"),
	item("shop_ascend", "effect", "Ascend", "legendary", "shop"),
	item("shop_diamond", "banner", "Diamond", "common", "shop"),
	item("shop_target", "banner", "Target", "rare", "shop"),
	item("shop_spade", "banner", "Spade", "rare", "shop"),
	item("shop_anchor", "banner", "Anchor", "epic", "shop"),
	item("shop_t_sniper", "title", "Line Breaker", "rare", "shop"),
	item("shop_t_ghost", "title", "Ghost", "epic", "shop"),
	item("shop_t_menace", "title", "Menace", "legendary", "shop"),
	-- the big ones, for Shards (in the shop's rotation like the rest)
	item("shop_feathers", "effect", "Feather Burst", "rare", "shop"),
	item("shop_sparkle", "effect", "Rainbow Sparkle", "epic", "shop"),
	item("shop_blocks", "effect", "Block Party", "rare", "shop"),
	item("shop_firework", "effect", "Firework", "epic", "shop"),
	item("shop_bubbles", "effect", "Bubble Pop", "rare", "shop"),
	item("shop_chicken", "effect", "Chicken", "legendary", "shop"),
	item("shop_duck", "effect", "Rubber Duck", "epic", "shop"),
	item("shop_balloons", "effect", "Balloon Ride", "legendary", "shop"),
	item("shop_banana", "effect", "Banana Slip", "epic", "shop"),
	item("shop_rainbowtrail", "trail", "Rainbow Road", "epic", "shop"),
	item("shop_feathertrail", "trail", "Feather Trail", "rare", "shop"),
	item("shop_bubbletrail", "trail", "Bubble Trail", "rare", "shop"),
	item("shop_pixelrain", "trail", "Pixel Rain", "epic", "shop"),
	item("shop_hearts", "trail", "Hearts", "rare", "shop"),
	item("shop_rainbowbow", "skin", "Rainbow Cycle", "legendary", "shop"),
	item("shop_lava", "skin", "Lava", "epic", "shop"),
	item("shop_galaxy", "skin", "Galaxy", "legendary", "shop"),
	item("shop_candy", "skin", "Candy Cane", "rare", "shop"),
	item("shop_frost", "skin", "Frostbite", "epic", "shop"),
	item("shop_flame", "banner", "Flame", "rare", "shop"),
	item("shop_rainbowbanner", "banner", "Rainbow", "epic", "shop"),
	item("shop_chickenbanner", "banner", "Chicken", "rare", "shop"),
	item("shop_skulls", "banner", "Skulls", "epic", "shop"),
	item("shop_galaxybanner", "banner", "Galaxy", "legendary", "shop"),
	-- the sword skins (the blade in the CHARGE; Shared/SwordSkins draws them)
	item("shop_chalkblade", "sword", "Chalk Blade", "common", "shop"),
	item("shop_inkblade", "sword", "Inkblade", "common", "shop"),
	item("shop_pixelsword", "sword", "Pixel Sword", "common", "shop"),
	item("shop_frostedge", "sword", "Frost Edge", "rare", "shop"),
	item("shop_gladius", "sword", "Golden Gladius", "rare", "shop"),
	item("shop_emberblade", "sword", "Ember Blade", "epic", "shop"),
	item("shop_neonkatana", "sword", "Neon Katana", "epic", "shop"),
	item("shop_cleaver", "sword", "Obsidian Cleaver", "epic", "shop"),
	item("shop_rainbowsaber", "sword", "Rainbow Saber", "legendary", "shop"),
	-- Robux only (Data/Shop.PREMIUM: a developer product each, yours for good; always in the shop, never rotated)
	item("rbx_lightning", "effect", "Lightning Strike", "legendary", "robux", { robux = 199 }),
	item("rbx_doge", "effect", "Much Wow", "legendary", "robux", { robux = 149 }),
	item("rbx_web", "effect", "Web Slinger", "legendary", "robux", { robux = 149 }),
	item("rbx_oof", "effect", "OOF", "epic", "robux", { robux = 99 }),
	item("rbx_bonk", "effect", "Bonk", "epic", "robux", { robux = 99 }),
	item("rbx_dance", "effect", "Dance Off", "legendary", "robux", { robux = 129 }),
	item("rbx_blackhole", "effect", "Black Hole", "legendary", "robux", { robux = 199 }),
	item("rbx_heaven", "effect", "Golden Gate", "legendary", "robux", { robux = 249 }),
	item("rbx_storm", "skin", "Storm Caller", "legendary", "robux", { robux = 149 }),
	item("rbx_dragon", "skin", "Golden Dragon", "legendary", "robux", { robux = 199 }),
	item("rbx_thunder", "trail", "Thunder Trail", "legendary", "robux", { robux = 99 }),
	item("rbx_lightningbanner", "banner", "Lightning", "epic", "robux", { robux = 49 }),
	item("rbx_dogebanner", "banner", "Doge", "epic", "robux", { robux = 49 }),
	item("rbx_crown", "banner", "Crown2", "legendary", "robux", { robux = 79 }),
	item("rbx_lightningfang", "sword", "Lightning Fang", "legendary", "robux", { robux = 149 }),
	item("rbx_dogeblade", "sword", "Doge Blade", "legendary", "robux", { robux = 129 }),
	item("rbx_scythe", "sword", "Shadow Scythe", "legendary", "robux", { robux = 199 }),
	-- earned only: goals (Data/Achievements)
	item("goal_sharp", "trail", "Crosshair Line", "epic", "goal"),
	item("goal_longshot", "trail", "Long Shot", "epic", "goal"),
	item("goal_bulldozer", "skin", "Bulldozer", "epic", "goal"),
	item("goal_centurion", "effect", "Centurion", "legendary", "goal"),
	item("goal_triple", "effect", "Triple Shatter", "epic", "goal"),
	item("goal_architect", "banner", "Blueprint", "epic", "goal"),
	item("goal_unbroken", "title", "Unbroken", "legendary", "goal"),
	item("goal_marathon", "title", "Marathoner", "rare", "goal"),
	item("goal_headhunter", "title", "Headhunter", "epic", "goal"),
	item("goal_comeback", "title", "Comeback Kid", "epic", "goal"),
	-- earned only: VIP (Data/Achievements.VIP)
	item("vip_title", "title", "VIP", "legendary", "vip"),
	item("vip_trail", "trail", "Afterimage", "legendary", "vip"),
	item("vip_effect", "effect", "VIP Shatter", "legendary", "vip"),
	item("vip_skin", "skin", "Inkwell", "legendary", "vip"),
	-- earned only: MVP
	item("mvp_title", "title", "MVP", "epic", "mvp", { mvps = 10 }),
	item("mvp_effect", "effect", "Spotlight", "legendary", "mvp", { mvps = 25 }),
	-- the Starter Pack
	item("starter_founder", "banner", "Founder", "legendary", "starter"),
}

local byKey = {}
for _, it in Cosmetics.list do
	byKey[it.key] = it
end
for _, s in Ladder.steps do
	byKey[s.key] = {
		key = s.key,
		kind = s.kind,
		name = s.name,
		rarity = s.big and "legendary" or (s.win > 60 and "epic" or (s.win > 25 and "rare" or "common")),
		source = "ladder",
		win = s.win,
		look = look(s.kind, s.name),
	}
end
for _, e in Extras.list do
	byKey[e.key] = { key = e.key, kind = e.kind, name = e.name, rarity = "rare", source = "extra", desc = e.desc }
	byKey[e.key].look = look(e.kind, e.name)
end

-- Season items are made from the season and the tier (Data/Season names them): "s<season>_<tier><track>"
local seasonItem -- (set by Data/Season, which knows what each tier gives)
function Cosmetics.setSeasonResolver(fn)
	seasonItem = fn
end

function Cosmetics.get(key)
	if type(key) ~= "string" then
		return nil
	end
	local it = byKey[key]
	if it then
		return it
	end
	if seasonItem and string.match(key, "^s%d+_%d+[fp]$") then
		it = seasonItem(key)
		if it then
			it.look = it.look or look(it.kind, it.name)
			byKey[key] = it
		end
		return it
	end
	return nil
end

-- A colour token for a team: "team", "light", "white", "ink".
local WHITE, INK = Color3.fromRGB(250, 250, 250), Color3.fromRGB(22, 22, 26)
local TEAM = Constants.TEAM_COLOR
local NAMED = {
	gold = Color3.fromRGB(255, 196, 40),
	yellow = Color3.fromRGB(255, 226, 60),
	pink = Color3.fromRGB(255, 105, 180),
	lava = Color3.fromRGB(255, 90, 20),
	ice = Color3.fromRGB(150, 220, 255),
	electric = Color3.fromRGB(120, 200, 255),
	galaxy = Color3.fromRGB(110, 60, 200),
	candy = Color3.fromRGB(230, 30, 50),
}
-- "rainbow": a hue that moves with time (t: seconds; nil: os.clock())
function Cosmetics.rainbow(t, offset)
	return Color3.fromHSV(((t or os.clock()) * 0.25 + (offset or 0)) % 1, 0.75, 1)
end
function Cosmetics.color(token, team)
	local c = TEAM[team or ""] or Color3.fromRGB(235, 40, 45)
	if typeof(token) == "Color3" then
		return token -- (a fixed colour, not a token: the plain sword's steel)
	elseif NAMED[token] then
		return NAMED[token]
	elseif token == "rainbow" then
		return Cosmetics.rainbow()
	elseif token == "team" then
		return c
	elseif token == "light" then
		return c:Lerp(WHITE, 0.5)
	elseif token == "ink" then
		return INK
	end
	return WHITE
end

-- A trail look for an equipped trail key (nil: the plain tracer).
function Cosmetics.trailLook(key)
	local it = Cosmetics.get(key)
	return it and it.kind == "trail" and it.look or nil
end

-- A lap of the ladder (II, III) draws its trail a little longer.
function Cosmetics.lap(name)
	local roman = string.match(name or "", " (I+)$")
	return roman and #roman or 1
end

return Cosmetics

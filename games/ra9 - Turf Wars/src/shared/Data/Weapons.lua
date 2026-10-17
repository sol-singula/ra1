--[[
The three bows (master plan §5) and the blade, all free from the start. Every hit is a knockout (one shot, every
bow, every charge): the bows differ in draw time, arrow speed, cadence, knockback and what they do to walls. The
blade only comes out in the CHARGE (the fight's last Constants.CHARGE_SECONDS, when the line opens and anyone may
run across): a slash knocks out anyone in reach, and its swing knocks arrows back at the archer (CombatService).

  draw        seconds to full charge (0 = fires at once, the crossbow)
  minCharge   the least charge a shot can have (a tap)
  damage      { min, max } by charge
  speed       { min, max } studs/s by charge
  cooldown    seconds after a shot before the next draw
  mag/reload  shots before a reload, and its seconds (the crossbow)
  knockback   studs/s pushed at full charge
  structure   damage multiplier on structures
  melee       (the blade) no arrow: a slash hits the nearest enemy within range studs, inside arc degrees of
              where you look; from behind (back) it does backstab x damage
]]
local Weapons = {}

Weapons.list = {
	{
		key = "bow",
		name = "Standard Bow",
		icon = "🏹",
		role = "Versatile: one hit, one knockout. Draw longer for a faster, straighter arrow.",
		draw = 0.9,
		minCharge = 0.25,
		damage = { 100, 100 },
		speed = { 110, 230 },
		cooldown = 0.25,
		knockback = 22,
		structure = 1,
		mag = nil,
		reload = nil,
	},
	{
		key = "crossbow",
		name = "Rapid Crossbow",
		icon = "🎯",
		role = "Aggressive: fast bolts, six to a magazine. Every bolt that hits is a knockout.",
		draw = 0,
		minCharge = 1,
		damage = { 100, 100 },
		speed = { 190, 190 },
		cooldown = 0.32,
		knockback = 10,
		structure = 0.7,
		mag = 6,
		reload = 1.7,
	},
	{
		key = "heavy",
		name = "Heavy Bow",
		icon = "💥",
		role = "Slow and brutal: a long draw, huge knockback, wrecks structures. One hit, one knockout.",
		draw = 1.5,
		minCharge = 0.4,
		damage = { 100, 100 },
		speed = { 120, 200 },
		cooldown = 0.5,
		knockback = 60,
		structure = 3,
		mag = nil,
		reload = nil,
	},
	{
		key = "blade",
		name = "Blade",
		icon = "🗡️",
		role = "At the line: a long slash knocks out anyone in reach, and it swats arrows back at the archer.",
		melee = true,
		draw = 0,
		minCharge = 1,
		damage = { 100, 100 },
		speed = { 0, 0 },
		cooldown = 0.5,
		knockback = 30,
		structure = 0.5,
		range = 10,
		arc = 55,
		backstab = 1.5,
		mag = nil,
		reload = nil,
	},
}

local byKey = {}
for i, w in Weapons.list do
	w.order = i
	byKey[w.key] = w
end

function Weapons.get(key)
	return byKey[key]
end

Weapons.DEFAULT = "bow"

return Weapons

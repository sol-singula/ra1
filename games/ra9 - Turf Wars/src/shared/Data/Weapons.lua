--[[
The bow, the TNT and the blade (1 2 3 on the hotbar). The bow and the blade are free; the TNT is a Robux unlock, for
good (Data/Shop TNT): until then its slot shows a lock and the price (Weapons.locked). Every bow hit is a knockout (one
shot, every charge). The TNT is thrown: hold to wind up (the charge is how far it goes), let go and it flies in a
lob and blows up where it lands (Constants.TNT_*: enemy structures in the blast break, enemies right by it are
knocked out, the rest are thrown back; a cooldown between throws). The blade only comes out in the CHARGE (the
fight's last Constants.CHARGE_SECONDS, when the line opens and anyone may run across): a slash knocks out anyone in
reach, and its swing knocks arrows back at the archer (CombatService).

  draw        seconds to full charge (0 = at once)
  minCharge   the least charge a shot can have (a tap)
  damage      { min, max } by charge
  speed       { min, max } studs/s by charge (the TNT: how hard it's thrown)
  cooldown    seconds after a shot before the next draw
  mag/reload  shots before a reload, and its seconds (none has a magazine now; the code still handles one)
  throw       (the TNT) no arrow: a lobbed explosive (CombatService:Throw)
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
		key = "tnt",
		name = "TNT",
		icon = "🧨",
		role = "Hold to wind up, let go to lob it. It blows up walls and knocks out anyone close.",
		throw = true,
		draw = 0.8,
		minCharge = 0.2,
		damage = { 100, 100 },
		speed = { 36, 112 }, -- (a long lob: well into the enemy's half at full wind-up)
		cooldown = 3,
		knockback = 0,
		structure = 1,
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

-- Not theirs yet: the TNT for a player who hasn't bought it (the "OwnsTNT" attribute, set by the server) and has no
-- free try ready ("TntTry": one throw an hour; "TntTryAt": os.time() the next one comes). Bots and nil: never locked.
function Weapons.locked(key, player)
	if key ~= "tnt" or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	return player:GetAttribute("OwnsTNT") ~= true and player:GetAttribute("TntTry") ~= true
end

-- Theirs only for the free try (one throw an hour, not bought)
function Weapons.trying(key, player)
	return key == "tnt"
		and typeof(player) == "Instance"
		and player:IsA("Player")
		and player:GetAttribute("OwnsTNT") ~= true
		and player:GetAttribute("TntTry") == true
end

return Weapons

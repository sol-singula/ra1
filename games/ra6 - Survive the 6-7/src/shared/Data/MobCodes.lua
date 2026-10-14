-- The codes in the monster snapshot (MonsterService.pack, MonsterController): which monster, and what it's doing.
-- Shared so the server and the client always agree. New entries go at the END of each list.
local MobCodes = {}

MobCodes.KINDS = { "kermy", "snapcap", "grinwolf", "pelter", "stumpy", "mimic", "mega_kermy" }

MobCodes.STATES = {
	"idle",
	"wander",
	"chase",
	"circle",
	"tell",
	"attack",
	"recover",
	"stagger",
	"flee",
	"guard",
	"eat",
	"sleep",
	"peek",
	"rooted",
	"tired",
	"faceplant",
	"gloat",
	"hidden",
	"show",
	"smash",
	"dead",
	"ko",
	"charge",
	"startled",
	"wake",
	"slam",
	"jump",
	"grab",
}

-- Flag bits
MobCodes.MOVING = 1
MobCodes.ELITE = 2
MobCodes.HIT = 4
MobCodes.STUNNED = 8
MobCodes.HIDDEN = 16
MobCodes.ROOTED = 32
MobCodes.ACT = 64 -- flips on every attack
MobCodes.HARMLESS = 128

MobCodes.KIND_INDEX = {}
for i, k in MobCodes.KINDS do
	MobCodes.KIND_INDEX[k] = i
end
MobCodes.STATE_INDEX = {}
for i, s in MobCodes.STATES do
	MobCodes.STATE_INDEX[s] = i
end

function MobCodes.has(flags, bit)
	return flags // bit % 2 == 1
end

-- Read a snapshot: server time, { { id, kind, x, y, z, yaw, hp (0..1), flags, state }, ... }
function MobCodes.unpack(s)
	local t, pos = string.unpack("<d", s)
	local out = {}
	while pos + 12 <= #s do
		local id, k, x, y, z, yaw, hp, flags, state
		id, k, x, y, z, yaw, hp, flags, state, pos = string.unpack("<I2BhhhBBBB", s, pos)
		table.insert(out, {
			id = id,
			kind = MobCodes.KINDS[k] or "snapcap",
			x = x / 10,
			y = y / 10,
			z = z / 10,
			yaw = yaw / 255 * math.pi * 2,
			hp = hp / 255,
			flags = flags,
			state = MobCodes.STATES[state] or "idle",
		})
	end
	return t, out
end

return MobCodes

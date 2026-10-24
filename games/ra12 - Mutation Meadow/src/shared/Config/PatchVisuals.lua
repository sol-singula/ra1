--[[
Patch the shopkeeper of Game Artist build-spec/05-patch.md, its tables as data. Models/Patch builds, poses and
faces him from these; PatchRigController times the pose tweens, the idle loop and the LOD on the client.
Offsets are from the origin O (the floor under Patch, front = -Z, the Counter in front of him); degrees.

  parts       section 2.1-2.3: { name, shape, size, offset, rot, hex, group, material?, transparency? }
              shape "block" | "ball" (a true Ball, size = diameter) | "ell" (an ellipsoid) | "cylV" | "wedge"
              group: which pose transform moves it ("counter" | "legs" | "body" | "armL" | "armR" | "head")
  face        section 2.4: the face parts (under PumpkinHead, offsets from the head centre) and each face's layout
  poses       section 4, in the spec's angles: lift (the whole character), lean (rx about the hips), head yaw /
              nod / tilt, and each arm's rx / rz (the spec raises an arm with a negative rx and opens it with
              +rz on the left; Models/Patch turns those into Roblox's rotations)
  tween / idle / wave / cheer / lod
]]
-- stylua: ignore start
local PatchVisuals = {}

PatchVisuals.parts = {
	-- 2.1 the counter
	{ name = "Root", shape = "block", size = { 0.2, 0.2, 0.2 }, offset = { 0, 0.1, 0 }, hex = "#7A4E2D", transparency = 1, group = "counter" },
	{ name = "Counter", shape = "block", size = { 8, 3, 3 }, offset = { 0, 1.5, -3.0 }, hex = "#BE8C5A", material = "WoodPlanks", group = "counter" },
	{ name = "CounterTop", shape = "block", size = { 8.2, 0.15, 3.2 }, offset = { 0, 3.075, -3.0 }, hex = "#A0784B", group = "counter" },
	-- 2.2 the body and limbs
	{ name = "Body", shape = "block", size = { 1.5, 1.6, 1.0 }, offset = { 0, 1.5, 0 }, hex = "#EADBB8", group = "body" },
	{ name = "Apron", shape = "block", size = { 1.55, 1.3, 0.12 }, offset = { 0, 1.35, -0.56 }, hex = "#5BC236", group = "body" },
	{ name = "ApronPocket", shape = "block", size = { 0.70, 0.55, 0.10 }, offset = { 0, 1.05, -0.66 }, hex = "#2E7D32", group = "body" },
	{ name = "SeedPacket", shape = "block", size = { 0.40, 0.50, 0.06 }, offset = { 0, 1.08, -0.74 }, rot = { 0, 0, 8 }, hex = "#FFF8E7", group = "body" },
	{ name = "SeedDot", shape = "ball", size = { 0.12 }, offset = { 0.05, 1.15, -0.78 }, hex = "#E63246", group = "body" },
	{ name = "ArmL", shape = "block", size = { 0.45, 1.2, 0.45 }, offset = { -1.05, 1.55, 0 }, rot = { 0, 0, 12 }, hex = "#5BC236", group = "armL" },
	{ name = "ArmR", shape = "block", size = { 0.45, 1.2, 0.45 }, offset = { 1.05, 1.55, 0 }, rot = { 0, 0, -12 }, hex = "#5BC236", group = "armR" },
	{ name = "HandL", shape = "ball", size = { 0.42 }, hand = "ArmL", hex = "#2E7D32", group = "armL" },
	{ name = "HandR", shape = "ball", size = { 0.42 }, hand = "ArmR", hex = "#2E7D32", group = "armR" },
	{ name = "LegL", shape = "block", size = { 0.45, 0.9, 0.45 }, offset = { -0.35, 0.55, 0 }, hex = "#5BC236", group = "legs" },
	{ name = "LegR", shape = "block", size = { 0.45, 0.9, 0.45 }, offset = { 0.35, 0.55, 0 }, hex = "#5BC236", group = "legs" },
	{ name = "FootL", shape = "block", size = { 0.55, 0.25, 0.70 }, offset = { -0.35, 0.18, -0.05 }, hex = "#7A4E2D", group = "legs" },
	{ name = "FootR", shape = "block", size = { 0.55, 0.25, 0.70 }, offset = { 0.35, 0.18, -0.05 }, hex = "#7A4E2D", group = "legs" },
	-- 2.3 the pumpkin head
	{ name = "PumpkinHead", shape = "ell", size = { 2.0, 1.7, 2.0 }, offset = { 0, 2.95, 0 }, hex = "#FF8C1A", group = "head" },
	{ name = "HeadShadeL", shape = "ell", size = { 0.55, 1.55, 1.85 }, offset = { -0.75, 2.90, 0 }, hex = "#D9661A", group = "head" },
	{ name = "HeadLight", shape = "ell", size = { 0.70, 0.90, 0.50 }, offset = { 0.35, 3.20, -0.85 }, hex = "#FFB066", group = "head" },
	{ name = "StemCurl", shape = "cylV", size = { 0.45, 0.28, 0.28 }, offset = { 0, 3.90, 0 }, hex = "#6B8E23", group = "head" },
	{ name = "StemTip", shape = "block", size = { 0.12, 0.12, 0.40 }, offset = { 0.05, 4.05, 0.15 }, rot = { 35, 0, 0 }, hex = "#6B8E23", group = "head" },
	{ name = "Cowlick", shape = "wedge", size = { 0.12, 0.35, 0.55 }, offset = { -0.55, 3.85, -0.2 }, rot = { 0, 40, -25 }, hex = "#2E7D32", group = "head" },
}
PatchVisuals.hip = 0.7 -- the bottom of Body: the lean pivots here
PatchVisuals.handDrop = 0.7 -- ArmHand C0 (0, -0.7, 0)

-- 2.4: all under PumpkinHead; the swap parts (MouthOpen, EyeLFlat, EyeRFlat, Brow) show only in their faces
PatchVisuals.face = {
	parts = {
		EyeL = { shape = "ball", size = { 0.28 }, hex = "#1E1B2E" },
		EyeR = { shape = "ball", size = { 0.28 }, hex = "#1E1B2E" },
		EyeShineL = { shape = "ball", size = { 0.08 }, hex = "#FFF8E7", lod = true },
		EyeShineR = { shape = "ball", size = { 0.08 }, hex = "#FFF8E7", lod = true },
		CheekL = { shape = "ball", size = { 0.18 }, hex = "#FF8FB1", lod = true },
		CheekR = { shape = "ball", size = { 0.18 }, hex = "#FF8FB1", lod = true },
		Mouth = { shape = "block", size = { 0.55, 0.10, 0.12 }, hex = "#1E1B2E" },
		MouthOpen = { shape = "ell", size = { 0.35, 0.30, 0.12 }, hex = "#1E1B2E" },
		EyeLFlat = { shape = "block", size = { 0.30, 0.06, 0.08 }, hex = "#1E1B2E" },
		EyeRFlat = { shape = "block", size = { 0.30, 0.06, 0.08 }, hex = "#1E1B2E" },
		Brow = { shape = "block", size = { 0.70, 0.06, 0.08 }, hex = "#1E1B2E" },
	},
	eyeL = { -0.40, 0.15, -0.90 },
	eyeR = { 0.40, 0.15, -0.90 },
	shine = { -0.06, 0.06, -0.12 }, -- from its eye
	cheekL = { -0.70, -0.15, -0.75 },
	cheekR = { 0.70, -0.15, -0.75 },
	cheekTransparency = 0.15,
	mouth = { 0, -0.35, -0.95 },
	-- [face] = the changes from happy
	faces = {
		happy = {},
		wow = { eyeSize = 0.36, open = true },
		thinking = {
			eyeL = { -0.32, 0.15, -0.90 }, eyeR = { 0.40, 0.11, -0.90 },
			mouth = { 0.08, -0.35, -0.95 }, mouthSize = { 0.35, 0.08, 0.10 }, brow = { 0.1, 0.40, -0.92 },
		},
		wink = { flatR = true }, -- the spec's "smile wider" has no size; the mouth stays happy's
		-- "small flat": the thinking mouth's size (the spec gives no other)
		sleepy = { flatL = true, flatR = true, mouthSize = { 0.35, 0.08, 0.10 }, cheekTransparency = 0.4, tilt = 8 },
	},
}

-- section 4 (the spec's angles; see the header)
PatchVisuals.poses = {
	idle = {},
	wave = { yaw = 15, armR = { -150, -20 } },
	point = { lean = -5, armR = { -90, 0 } },
	cheer = { lift = { 0, 0.3, 0 }, armL = { -160, 0 }, armR = { -160, 0 } },
	announce = { lean = -8, nod = -10, armL = { -40, 25 }, armR = { -40, -25 } },
	lean = { lift = { 0, 0, -0.6 }, lean = -15, armL = { -70, 0 }, armR = { -70, 0 } },
}
PatchVisuals.rest = { armL = { 0, 12 }, armR = { 0, -12 } } -- the arms' rest rz (section 2.2), in the spec's sense

PatchVisuals.tween = {
	wave = { sec = 0.25, style = "quad" }, point = { sec = 0.25, style = "quad" },
	cheer = { sec = 0.35, style = "back" }, announce = { sec = 0.35, style = "back" },
	-- idle and lean have no tween in the table; they take the 0.25 s Quad Out
	idle = { sec = 0.25, style = "quad" }, lean = { sec = 0.25, style = "quad" },
}
PatchVisuals.idle = { breath = 0.04, breathSec = 2, yaw = 6, yawSec = 4 }
PatchVisuals.wave = { wiggle = 25, hz = 4, sec = 1.2 }
PatchVisuals.cheer = { landSec = 0.4 }
PatchVisuals.lod = { studs = 120, hide = { "SeedPacket", "SeedDot", "Cowlick" } } -- + the face's lod parts
-- stylua: ignore end

return PatchVisuals

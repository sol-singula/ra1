--[[
The kill effects' sticker art (KillEffects): bold comic stickers (the doge, the web, the bolt, OOF, BONK, the
chicken...), uploaded to Roblox as decals. Drawn by tools in the scratchpad (memeart/draw.py), swappable for
better art any time: upload a new decal and change its id here.

A decal's id isn't its image's id, and only a game server can look that up (InsertService), so MemeArtService
does it at start and puts each image on ReplicatedStorage as an attribute ("Art_<name>"). Until then (or if it
fails) the art shows through the decal's own thumbnail, which is the same picture.

  MemeArt.DECALS[name]      the decal id
  MemeArt.image(name)       the best image to show now ("" for an unknown name)
  MemeArt.FOR_ITEM[key]     the sticker for a cosmetic's shop card (nil: none)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemeArt = {}

MemeArt.DECALS = {
	banana = 122075236033010,
	bawk = 99658113581647,
	blackhole = 102067977618308,
	bolt = 130961077200085,
	bonk = 91203457658736,
	chicken = 134635993987989,
	disco = 111462273667504,
	doge = 92598050857344,
	doge_word1 = 124350377030915,
	doge_word2 = 133886755297940,
	doge_word3 = 127873108164098,
	doge_word4 = 124425579511328,
	duck = 104237346907462,
	gg = 84638332443979,
	heaven = 123231124003204,
	mallet = 132460293953033,
	oof = 103750122891636,
	splat = 108520809095938,
	thwip = 126659689140677,
	web = 94065394968348,
	zap = 111341297152513,
}

-- The sticker that shows an item in the shop (its card's picture)
MemeArt.FOR_ITEM = {
	rbx_doge = "doge",
	rbx_web = "web",
	rbx_lightning = "bolt",
	rbx_oof = "oof",
	rbx_bonk = "bonk",
	rbx_dance = "disco",
	rbx_blackhole = "blackhole",
	rbx_heaven = "heaven",
	rbx_dogebanner = "doge",
	rbx_lightningbanner = "bolt",
	shop_chicken = "chicken",
	shop_duck = "duck",
	shop_banana = "banana",
	shop_chickenbanner = "chicken",
}

function MemeArt.image(name)
	local id = MemeArt.DECALS[name]
	if not id then
		return ""
	end
	local resolved = ReplicatedStorage:GetAttribute("Art_" .. name)
	if type(resolved) == "string" and resolved ~= "" then
		return resolved
	end
	return `rbxthumb://type=Asset&id={id}&w=420&h=420`
end

return MemeArt

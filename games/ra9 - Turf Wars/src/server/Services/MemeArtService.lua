--[[
Looks up the image behind each sticker decal (Data/MemeArt) once at start, so the kill effects show the full
picture: InsertService loads the decal (ours: the game's owner made them) and its Texture is the image. Each goes on
ReplicatedStorage as "Art_<name>"; a failure just leaves the decal thumbnail in use.
]]
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemeArt = require(ReplicatedStorage.Shared.Data.MemeArt)

local MemeArtService = { Name = "MemeArtService", Dependencies = {} }

function MemeArtService:Resolve(name, id)
	local ok, texture = pcall(function()
		local model = InsertService:LoadAsset(id)
		local decal = model and model:FindFirstChildWhichIsA("Decal", true)
		local t = decal and decal.Texture
		model:Destroy()
		return t
	end)
	if ok and type(texture) == "string" and texture ~= "" then
		ReplicatedStorage:SetAttribute("Art_" .. name, texture)
		return texture
	end
	return nil
end

function MemeArtService:Start()
	for name, id in MemeArt.DECALS do
		task.spawn(function()
			self:Resolve(name, id)
		end)
	end
end

return MemeArtService

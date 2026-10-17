--[[
Invite a friend, both get something: the HUD's INVITE button opens Roblox's invite prompt with LaunchData
"i:<your UserId>". When the friend joins from it, the friend gets the Buddy Trail (Data/Extras) and so do you,
each with a card. A share link works too (Roblox's ReferredByPlayerId).

  * The friend is credited once ever (profile.invite.by): rejoining from another invite gives nothing more.
  * You're credited once per friend (profile.invite.friends), and the trail is given once; each new friend still
    gets you a "joined from your invite" card and counts in profile.invite.count.
  * You and they must be Roblox friends (Players:IsFriendsWith) and not the same account.
  * Not in the same server (an invite usually lands them in yours, but not always)? Your credit waits in a
    DataStore and is claimed the next time you join.

  InviteService.Credited (inviter, friendUserId)
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local InviteService = {
	Name = "InviteService",
	Dependencies = { "PlayerDataService", "ProgressService" },
	Credited = Signal.new("InviteService.Credited"), -- (inviter, friendUserId)
}

local BUDDY = "extra_buddy"
local STORE_NAME = "TWO_InviteCredits_v1"
local PENDING_MAX = 50
local data, progress, store

-- Who invited this player, from how they joined (nil if nobody).
function InviteService.inviterOf(player)
	local ok, jd = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(jd) ~= "table" then
		return nil
	end
	local id = type(jd.LaunchData) == "string" and tonumber(string.match(jd.LaunchData, "^i:(%d+)$")) or nil
	if not id and tonumber(jd.ReferredByPlayerId) and jd.ReferredByPlayerId ~= 0 then
		id = tonumber(jd.ReferredByPlayerId)
	end
	return id
end

local function inviteOf(profile)
	profile.invite = profile.invite or {}
	local inv = profile.invite
	inv.friends = inv.friends or {}
	inv.count = inv.count or 0
	return inv
end

-- The inviter's side: once per friend.
function InviteService:Credit(inviter, friendId, friendName)
	local p = data:Get(inviter)
	if not p then
		return false
	end
	local inv = inviteOf(p)
	local k = tostring(friendId)
	if inv.friends[k] then
		return false
	end
	inv.friends[k] = true
	inv.count += 1
	data:WhenClientReady(inviter, function()
		progress:GrantExtra(inviter, BUDDY, { title = "FRIEND JOINED!", line = `{friendName} came from your invite` })
	end)
	self.Credited:Fire(inviter, friendId)
	return true
end

-- Credits that came in while the inviter was somewhere else.
function InviteService:Claim(player)
	if not store then
		return
	end
	local got
	pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) ~= "table" or #old == 0 then
				return nil
			end
			got = old
			return {}
		end)
	end)
	for _, c in got or {} do
		self:Credit(player, c.id, c.name or "A friend")
	end
end

local function queue(inviterId, friendId, friendName)
	if not store then
		return
	end
	pcall(function()
		store:UpdateAsync(tostring(inviterId), function(old)
			old = type(old) == "table" and old or {}
			if #old < PENDING_MAX then
				table.insert(old, { id = friendId, name = friendName })
			end
			return old
		end)
	end)
end

-- The friend's side: once ever.
function InviteService:Joined(player, profile)
	local by = InviteService.inviterOf(player)
	local inv = inviteOf(profile)
	if not by or by == player.UserId or inv.by ~= nil then
		return false
	end
	local okF, friends = pcall(function()
		return player:IsFriendsWith(by)
	end)
	if okF and not friends then
		return false
	end
	inv.by = by
	local inviter = Players:GetPlayerByUserId(by)
	local inviterName = inviter and inviter.DisplayName or "A friend"
	data:WhenClientReady(player, function()
		progress:GrantExtra(
			player,
			BUDDY,
			{ title = "A FRIEND INVITED YOU!", line = `{inviterName} · you both get the Buddy Trail` }
		)
	end)
	if inviter and data:Get(inviter) then
		self:Credit(inviter, player.UserId, player.DisplayName)
	else
		task.spawn(queue, by, player.UserId, player.DisplayName)
	end
	return true
end

function InviteService:Init(registry)
	data = registry.PlayerDataService
	progress = registry.ProgressService
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and s or nil
end

function InviteService:OnPlayerReady(player, profile)
	self:Joined(player, profile)
	task.spawn(self.Claim, self, player)
end

return InviteService

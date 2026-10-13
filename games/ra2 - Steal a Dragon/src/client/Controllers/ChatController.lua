-- Chat tags and name colours (Roblox's TextChatService; what players type is still filtered by Roblox):
--   [ADMIN]        red tag, red name           (Constants.ADMINS)
--   [TOP SPENDER]  purple tag, purple name     (only the #1 spender on the TOP SPENDERS board: LeaderboardService)
--   [VIP]          gold tag, gold name         (bought or gifted VIP)
--   everyone else  light green name
-- One tag each, in that order. The message text itself stays white so chat is easy to read. The server sets the
-- player attributes these read (Admin, TopSpender, VIP).
local Players = game:GetService("Players")

local ChatController = { Name = "ChatController", Order = 95 }

local STYLES = {
	{ attr = "Admin", tag = "[ADMIN]", color = "#FF3C3C" },
	{ attr = "TopSpender", tag = "[TOP SPENDER]", color = "#B46EFF" },
	{ attr = "VIP", tag = "[VIP]", color = "#FFCD32" },
}
local EVERYONE = "#9CFF9C" -- light green

-- The prefix (tag + coloured name) for a player's chat message.
function ChatController.prefix(player, name)
	for _, style in STYLES do
		if player and player:GetAttribute(style.attr) then
			return `<font color="{style.color}"><b>{style.tag}</b></font> <font color="{style.color}">{name}</font>`
		end
	end
	return `<font color="{EVERYONE}">{name}</font>`
end

function ChatController:init()
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		TextChatService.OnIncomingMessage = function(message)
			local props = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			if source then
				local player = Players:GetPlayerByUserId(source.UserId)
				props.PrefixText = ChatController.prefix(player, message.PrefixText)
			end
			return props
		end
	end)
end

return ChatController

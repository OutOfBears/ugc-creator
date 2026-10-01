local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientAtoms = require("./ClientAtoms")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)

local nextMessageId = 0

--[=[
	@class Message
	@client

	A banner that drops in from the top of the screen, holds, and slides back out, rendered by the
	`Messages` view from `ClientAtoms.messages`.
]=]
local Message = {}

--[=[
	@within Message
	@yields
	@param text string -- the message to show

	Shows a banner and blocks until it has slid back off screen.
]=]
function Message.create(text: string)
	nextMessageId += 1
	local message = { id = nextMessageId, text = text }

	ClientAtoms.messages(function(messages)
		local nextMessages = table.clone(messages)
		table.insert(nextMessages, message)

		return nextMessages
	end)

	local timing = CreationConfig.message
	task.wait(timing.holdSeconds + timing.slideSeconds)

	ClientAtoms.messages(function(messages)
		local nextMessages = table.clone(messages)
		table.remove(nextMessages, table.find(nextMessages, message))

		return nextMessages
	end)
end

return Message

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class CommerceController
	@client

	Client side of monetization. Wire purchase/equip intents and reactions to completed
	`MarketplaceService` purchases here as the shop grows.
]=]
local CommerceController = {} :: Types.Controller

function CommerceController.onInit() end

return CommerceController

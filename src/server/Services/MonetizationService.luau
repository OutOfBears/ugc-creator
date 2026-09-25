local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class MonetizationService
	@server

	Owns the single `MarketplaceService.ProcessReceipt` handler and grants the effect of a
	purchased developer product. Map each product id to its grant in `deliverProduct`.
]=]
local MonetizationService = {} :: Types.Service & {
	grantProduct: (player: Player, productId: number) -> boolean,
}

local granted: { [string]: true } = {}

local function deliverProduct(_player: Player, _productId: number): boolean
	return false
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = `{receiptInfo.PlayerId}:{receiptInfo.PurchaseId}`
	if granted[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not deliverProduct(player, receiptInfo.ProductId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	granted[receiptKey] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[=[
	@within MonetizationService
	@param player Player -- the player to grant the product's effect to
	@param productId number -- the developer product id
	@return boolean -- true if the product was recognised and delivered

	Runs a product's grant path directly, with no receipt or idempotency — used by the
	`giveProduct` command. Returns false for a product with no server-side effect (an
	unimplemented consumable or a gamepass-unlock product).
]=]
function MonetizationService.grantProduct(player: Player, productId: number): boolean
	return deliverProduct(player, productId)
end

function MonetizationService.onInit()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService

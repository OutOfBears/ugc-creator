local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Konsole = require(ReplicatedStorage.Packages.Konsole)

local MonetizationService = require("../../MonetizationService")

export type Definition = Konsole.Definition

local function run(context: Konsole.Context, target: Player?, productId: number?)
	if not target then
		return context.err("no-target", "no target player")
	end

	if not productId then
		return context.err("no-product", "no product id")
	end

	if not MonetizationService.grantProduct(target, productId) then
		return context.err("not-grantable", `product {productId} has no server-side grant`)
	end

	return context.reply(`gave product {productId} to {target.Name}`)
end

return table.freeze({
	name = "giveProduct",
	rank = 100,
	aliases = { "giveproduct" },
	description = "Grants a developer product's effect to the target player.",
	server = "giveProduct",
	args = {
		{
			name = "target",
			type = "player",
			required = true,
			suggestions = { "me" },
		},
		{
			name = "productId",
			type = "number",
			required = true,
		},
	},
	run = run,
}) :: Definition

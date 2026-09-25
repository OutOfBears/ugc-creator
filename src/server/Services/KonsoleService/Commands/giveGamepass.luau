local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage.Shared.Data.GamePasses)
local Konsole = require(ReplicatedStorage.Packages.Konsole)

local GamePassService = require("../../GamePassService")

export type Definition = Konsole.Definition

local passes = GamePasses :: { [string]: number }

local suggestions = {}
for key in passes do
	table.insert(suggestions, key)
end
table.sort(suggestions)

local function run(context: Konsole.Context, target: Player?, pass: string?)
	if not target then
		return context.err("no-target", "no target player")
	end

	if not pass then
		return context.err("no-pass", "no gamepass")
	end

	local passId = passes[pass]
	if passId == nil then
		return context.err("unknown-pass", `no gamepass named "{pass}"`)
	end

	if passId <= 0 then
		return context.err("unconfigured-pass", `gamepass "{pass}" has no product id yet`)
	end

	if not GamePassService.grant(target, passId) then
		return context.err("grant-failed", "could not grant gamepass")
	end

	return context.reply(`gave {pass} gamepass to {target.Name}`)
end

return table.freeze({
	name = "giveGamepass",
	rank = 100,
	aliases = { "givegamepass", "givepass" },
	description = "Grants a gamepass to the target player (persisted and replicated).",
	server = "giveGamepass",
	args = {
		{
			name = "target",
			type = "player",
			required = true,
			suggestions = { "me" },
		},
		{
			name = "pass",
			type = "string",
			required = true,
			suggestions = suggestions,
		},
	},
	run = run,
}) :: Definition

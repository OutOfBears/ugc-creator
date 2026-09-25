local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Profile = require("./ServerPlayerProfile")
local Types = require(ReplicatedStorage.Shared.Types)

type Replicator = AttributeReplicator.AttributeReplicator<Instance, any>
type Profile = Profile.Profile
type BehaviorBase<I> = Behavior.BehaviorBase<I>
--[=[
	@class ServerPlayer
	@server

	Server-side component representing a connected player for the current session.
	Holds the player's replicated session state and the logic operating on it.
]=]

--[=[
	@interface ServerPlayer
	@within ServerPlayer
	.replicator Replicator -- attribute replicator carrying the player's session state
]=]
export type ServerPlayer = BehaviorBase<Instance> & {
	-- vars
	userId: number,
	ranks: Types.GroupRoles,
	replicator: Replicator,
	-- methods
	init: (self: ServerPlayer) -> (),
	destroy: (self: ServerPlayer) -> (),
}

local function ServerPlayer(instance: Instance, replicator: Replicator)
	local maid = Maid.new()
	local entity = {} :: ServerPlayer

	entity.instance = instance
	entity.replicator = replicator

	entity.ranks = {}
	entity.userId = instance.UserId
	entity.replicator:Hook(entity)

	function entity:init() end

	function entity:destroy()
		maid:doCleaning()
	end

	entity:init()
	return entity
end

return Behavior("Player", ServerPlayer, {
	state = {
		isDev = nil :: boolean?,
	},
	replicated = true,
})

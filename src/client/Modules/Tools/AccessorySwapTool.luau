local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryActions = require(ReplicatedStorage.Shared.Modules.Actions.AccessoryActions)
local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()

export type AccessorySwapTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	selections: Charm.Atom<{ [string]: number }>,
	maid: Maid.Maid,
	-- methods
	selectOption: (self: AccessorySwapTool, slotName: string, optionIndex: number) -> boolean,
	destroy: (self: AccessorySwapTool) -> (),
}

--[=[
	@class AccessorySwapTool
	@client

	Swaps the accessory merged into each slot of a head base (e.g. fox ears for bear ears). The
	swap runs locally through a `SelectAccessory` action and is mirrored to the server.

	`selections` is a snapshot of the chosen option per slot, republished after every swap, for the
	UI to subscribe to.
]=]
local function AccessorySwapTool(modelInfo: ModelInfo.ModelInfo): AccessorySwapTool
	local maid = Maid.new()
	local object = {} :: AccessorySwapTool

	assert(modelInfo:getAccessoryCatalog(), "AccessorySwapTool requires a blank with an accessory catalog")

	object.modelInfo = modelInfo
	object.selections = Charm.atom(table.clone(modelInfo:getAccessorySelections()))
	object.maid = maid

	--[=[
		@within AccessorySwapTool
		@param slotName string -- the slot to change, e.g. `"Ears"`
		@param optionIndex number -- 1-based option, or 0 to empty an optional slot
		@return boolean -- false if the swap was rejected (e.g. already selected)
	]=]
	function object:selectOption(slotName: string, optionIndex: number): boolean
		local metadata: AccessoryActions.SelectAccessoryActionMetadata = {
			slotName = slotName,
			optionIndex = optionIndex,
		}

		local action = Actions.createAction(Actions.ActionTypes.SelectAccessory, metadata)
		if not Actions.executeAction(self.modelInfo, action) then
			return false
		end

		Network.fire("SubmitAction", action)
		self.selections(table.clone(self.modelInfo:getAccessorySelections()))

		return true
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return AccessorySwapTool

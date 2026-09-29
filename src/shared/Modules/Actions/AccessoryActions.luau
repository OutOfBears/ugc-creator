--[=[
	@class AccessoryActions

	Action processors for swapping the accessories merged into a head base (ears, horns, …). The
	swap itself lives on [ModelInfo], which both sides run so their meshes stay in step.
]=]

local ModelInfo = require("../ModelInfo")

export type AccessoryAction = {
	isValidAction: (modelInfo: any, actionMetaData: any) -> boolean,
	executeAction: (modelInfo: any, actionMetaData: any) -> (),
}

export type SelectAccessoryActionMetadata = {
	slotName: string,
	optionIndex: number,
}

local AccessoryActions = {}

--[=[
	@within AccessoryActions
	@prop SelectAccessoryAction AccessoryAction

	Replaces the option merged into one slot. Index 0 empties the slot, which only optional slots
	allow; re-selecting the current option is rejected so it doesn't wipe that cell's paint.
]=]
AccessoryActions.SelectAccessoryAction = {
	isValidAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: SelectAccessoryActionMetadata)
		local slotName = actionMetaData.slotName
		local optionIndex = actionMetaData.optionIndex
		if typeof(slotName) ~= "string" or typeof(optionIndex) ~= "number" or optionIndex % 1 ~= 0 then
			return false
		end

		local slot = modelInfo:getAccessorySlot(slotName)
		if not slot then
			return false
		end
		if modelInfo:getAccessorySelections()[slotName] == optionIndex then
			return false
		end

		local minIndex = if slot.optional then 0 else 1

		return optionIndex >= minIndex and optionIndex <= #slot.options
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: SelectAccessoryActionMetadata)
		modelInfo:setAccessory(actionMetaData.slotName, actionMetaData.optionIndex)
	end,
}

return AccessoryActions

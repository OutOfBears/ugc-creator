--[=[
	@class PaintLayerActions

	Action processors for the player's paint layer stack — adding, removing, reordering, hiding
	and re-blending layers. Every processor re-merges the color maps so both sides stay in step.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local TextureUtils = require("../Utils/TextureUtils")

export type PaintLayerAction = {
	isValidAction: (modelInfo: any, actionMetaData: any) -> boolean,
	executeAction: (modelInfo: any, actionMetaData: any) -> (),
}

export type AddPaintLayerActionMetadata = {
	layerId: string,
}

export type RemovePaintLayerActionMetadata = {
	layerId: string,
}

export type MovePaintLayerActionMetadata = {
	layerId: string,
	toIndex: number,
}

export type SetPaintLayerBlendModeActionMetadata = {
	layerId: string,
	blendMode: string,
}

export type SetPaintLayerVisibleActionMetadata = {
	layerId: string,
	visible: boolean,
}

local PaintLayerActions = {}

local function hasPaintLayer(modelInfo, layerId: any): boolean
	return typeof(layerId) == "string" and modelInfo:getTextureInfo():getPaintLayer(layerId) ~= nil
end

local function isBlendMode(blendMode: any): boolean
	return table.find(CreationConfig.paintBlendModeOrder, blendMode) ~= nil
end

--[=[
	@within PaintLayerActions
	@prop AddPaintLayerAction PaintLayerAction

	Adds an empty Normal layer on top of the stack. It adds nothing when the image budget is full.
]=]
PaintLayerActions.AddPaintLayerAction = {
	isValidAction = function(modelInfo, actionMetaData: AddPaintLayerActionMetadata)
		local layerId = actionMetaData.layerId
		if typeof(layerId) ~= "string" or #layerId == 0 or #layerId > CreationConfig.maxPaintLayerIdLength then
			return false
		end

		local textureInfo = modelInfo:getTextureInfo()
		if textureInfo:getPaintLayer(layerId) then
			return false
		end

		return #textureInfo:getPaintLayers() < CreationConfig.maxPaintLayers
	end,
	executeAction = function(modelInfo, actionMetaData: AddPaintLayerActionMetadata)
		modelInfo:getTextureInfo():addPaintLayer(actionMetaData.layerId)
	end,
}

--[=[
	@within PaintLayerActions
	@prop RemovePaintLayerAction PaintLayerAction

	Deletes a layer along with its paint and every sticker placed on it. The last layer can't be
	removed.
]=]
PaintLayerActions.RemovePaintLayerAction = {
	isValidAction = function(modelInfo, actionMetaData: RemovePaintLayerActionMetadata)
		if not hasPaintLayer(modelInfo, actionMetaData.layerId) then
			return false
		end

		return #modelInfo:getTextureInfo():getPaintLayers() > 1
	end,
	executeAction = function(modelInfo, actionMetaData: RemovePaintLayerActionMetadata)
		local textureInfo = modelInfo:getTextureInfo()

		for _, stickerLayerName in textureInfo:getStickerLayerNamesOnPaintLayer(actionMetaData.layerId) do
			for meshPart in textureInfo:getUniqueLayerMap() do
				if textureInfo:hasLayer(meshPart, stickerLayerName) then
					TextureUtils.clear((textureInfo:getOrCreateLayer(meshPart, stickerLayerName)))
					textureInfo:removeLayer(meshPart, stickerLayerName)
				end
			end

			textureInfo:setStickerPaintLayer(stickerLayerName, nil)
		end

		textureInfo:removePaintLayer(actionMetaData.layerId)
		modelInfo:updateOutputColorMap()
	end,
}

--[=[
	@within PaintLayerActions
	@prop MovePaintLayerAction PaintLayerAction

	Moves a layer to a new position in the stack, 1 being the bottom.
]=]
PaintLayerActions.MovePaintLayerAction = {
	isValidAction = function(modelInfo, actionMetaData: MovePaintLayerActionMetadata)
		if not hasPaintLayer(modelInfo, actionMetaData.layerId) then
			return false
		end

		local toIndex = actionMetaData.toIndex
		if typeof(toIndex) ~= "number" or toIndex % 1 ~= 0 then
			return false
		end

		return toIndex >= 1 and toIndex <= #modelInfo:getTextureInfo():getPaintLayers()
	end,
	executeAction = function(modelInfo, actionMetaData: MovePaintLayerActionMetadata)
		modelInfo:getTextureInfo():movePaintLayer(actionMetaData.layerId, actionMetaData.toIndex)
		modelInfo:updateOutputColorMap()
	end,
}

--[=[
	@within PaintLayerActions
	@prop SetPaintLayerBlendModeAction PaintLayerAction

	Changes how a layer combines with the layers beneath it.
]=]
PaintLayerActions.SetPaintLayerBlendModeAction = {
	isValidAction = function(modelInfo, actionMetaData: SetPaintLayerBlendModeActionMetadata)
		return hasPaintLayer(modelInfo, actionMetaData.layerId) and isBlendMode(actionMetaData.blendMode)
	end,
	executeAction = function(modelInfo, actionMetaData: SetPaintLayerBlendModeActionMetadata)
		modelInfo:getTextureInfo():setPaintLayerBlendMode(actionMetaData.layerId, actionMetaData.blendMode)
		modelInfo:updateOutputColorMap()
	end,
}

--[=[
	@within PaintLayerActions
	@prop SetPaintLayerVisibleAction PaintLayerAction

	Shows or hides a layer; a hidden layer is left out of the merged color map.
]=]
PaintLayerActions.SetPaintLayerVisibleAction = {
	isValidAction = function(modelInfo, actionMetaData: SetPaintLayerVisibleActionMetadata)
		return hasPaintLayer(modelInfo, actionMetaData.layerId) and typeof(actionMetaData.visible) == "boolean"
	end,
	executeAction = function(modelInfo, actionMetaData: SetPaintLayerVisibleActionMetadata)
		modelInfo:getTextureInfo():setPaintLayerVisible(actionMetaData.layerId, actionMetaData.visible)
		modelInfo:updateOutputColorMap()
	end,
}

return PaintLayerActions

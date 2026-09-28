local AccessoryActions = require("./Actions/AccessoryActions")
local ImageEditActions = require("./Actions/ImageEditActions")
local MeshEditActions = require("./Actions/MeshEditActions")
local ModelInfo = require("./ModelInfo")
local PaintLayerActions = require("./Actions/PaintLayerActions")

export type Action = {
	actionType: string,
	actionMetaData: {},
}

local ActionTypes = {
	Recolor = "Recolor",
	RecolorRegion = "RecolorRegion",
	ApplyPBRToRegion = "ApplyPBRToRegion",
	BrushStroke = "BrushStroke",
	ClearBrush = "ClearBrush",
	LinearBrush = "LinearBrush",
	Sticker = "Sticker",
	ProjectedSticker = "ProjectedSticker",
	TiledSticker = "TiledSticker",
	RemoveSticker = "RemoveSticker",
	Clear = "Clear",
	ClearRegion = "ClearRegion",
	ProjectionBrush = "ProjectionBrush",
	RecolorSection = "RecolorSection",
	SelectVariant = "SelectVariant",

	AddPaintLayer = "AddPaintLayer",
	RemovePaintLayer = "RemovePaintLayer",
	MovePaintLayer = "MovePaintLayer",
	SetPaintLayerBlendMode = "SetPaintLayerBlendMode",
	SetPaintLayerVisible = "SetPaintLayerVisible",

	UpdateWidgetPosition = "UpdateWidgetPosition",
	UpdateAttachmentsPositions = "UpdateAttachmentsPositions",
	MergeKitbashPiece = "MergeKitbashPiece",
	UnmergeKitbashPiece = "UnmergeKitbashPiece",
	UpdateDeformedEditableMeshes = "UpdateDeformedEditableMeshes",

	SelectAccessory = "SelectAccessory",
}

local ACTION_PROCESSOR_MAP = {
	[ActionTypes.Recolor] = ImageEditActions.RecolorAction,
	[ActionTypes.RecolorRegion] = ImageEditActions.RecolorRegionAction,
	[ActionTypes.ApplyPBRToRegion] = ImageEditActions.ApplyPBRToRegionAction,
	[ActionTypes.BrushStroke] = ImageEditActions.BrushStrokeAction,
	[ActionTypes.ClearBrush] = ImageEditActions.ClearBrushAction,
	[ActionTypes.LinearBrush] = ImageEditActions.LinearBrushAction,
	[ActionTypes.Sticker] = ImageEditActions.StickerAction,
	[ActionTypes.ProjectedSticker] = ImageEditActions.ProjectedStickerAction,
	[ActionTypes.TiledSticker] = ImageEditActions.TiledStickerAction,
	[ActionTypes.RemoveSticker] = ImageEditActions.RemoveStickerAction,
	[ActionTypes.Clear] = ImageEditActions.ClearAction,
	[ActionTypes.ClearRegion] = ImageEditActions.ClearRegionAction,
	[ActionTypes.ProjectionBrush] = ImageEditActions.ProjectionBrushAction,
	[ActionTypes.RecolorSection] = ImageEditActions.RecolorSectionAction,
	[ActionTypes.SelectVariant] = ImageEditActions.SelectVariantAction,

	[ActionTypes.AddPaintLayer] = PaintLayerActions.AddPaintLayerAction,
	[ActionTypes.RemovePaintLayer] = PaintLayerActions.RemovePaintLayerAction,
	[ActionTypes.MovePaintLayer] = PaintLayerActions.MovePaintLayerAction,
	[ActionTypes.SetPaintLayerBlendMode] = PaintLayerActions.SetPaintLayerBlendModeAction,
	[ActionTypes.SetPaintLayerVisible] = PaintLayerActions.SetPaintLayerVisibleAction,

	[ActionTypes.UpdateWidgetPosition] = MeshEditActions.UpdateWidgetPositionAction,
	[ActionTypes.UpdateAttachmentsPositions] = MeshEditActions.UpdateAttachmentsPositionsAction,
	[ActionTypes.MergeKitbashPiece] = MeshEditActions.MergeKitbashPieceAction,
	[ActionTypes.UnmergeKitbashPiece] = MeshEditActions.UnmergeKitbashPieceAction,
	[ActionTypes.UpdateDeformedEditableMeshes] = MeshEditActions.UpdateDeformedEditableMeshesAction,

	[ActionTypes.SelectAccessory] = AccessoryActions.SelectAccessoryAction,
}

--[=[
	@class Actions

	The registry every edit goes through. An edit is described as an [Actions.Action] — a type
	string plus its metadata — which lets the client send the same value over the wire that it
	applied locally, and lets the server re-validate it before applying it to its own model.

	`Actions.ActionTypes` holds the type strings; they cross the network, so they are never
	renamed.
]=]

--[=[
	@within Actions
	@param actionType string -- an `Actions.ActionTypes` value
	@param actionMetaData {} -- the payload the matching processor expects
	@return Action -- the packaged action
]=]
local function createAction(actionType: string, actionMetaData: {}): Action
	local newAction: Action = {
		actionType = actionType,
		actionMetaData = actionMetaData,
	}

	return newAction
end

--[=[
	@within Actions
	@param actionType string -- the type string to look up
	@return boolean -- true if a processor is registered for it
]=]
local function isKnownActionType(actionType: string): boolean
	return ACTION_PROCESSOR_MAP[actionType] ~= nil
end

--[=[
	@within Actions
	@param modelInfo ModelInfo -- the model the action would be applied to
	@param action Action -- the action to check
	@return boolean -- true if the action is known and its processor accepts the metadata
]=]
local function isValidAction(modelInfo: ModelInfo.ModelInfo, action: Action): boolean
	if not isKnownActionType(action.actionType) then
		return false
	end

	if not ACTION_PROCESSOR_MAP[action.actionType].isValidAction(modelInfo, action.actionMetaData) then
		return false
	end

	return true
end

--[=[
	@within Actions
	@param modelInfo ModelInfo -- the model to apply the action to
	@param action Action -- the action to apply
	@return boolean -- false if the action was rejected, in which case nothing was applied
]=]
local function executeAction(modelInfo: ModelInfo.ModelInfo, action: Action): boolean
	if not isValidAction(modelInfo, action) then
		return false
	end

	ACTION_PROCESSOR_MAP[action.actionType].executeAction(modelInfo, action.actionMetaData)

	return true
end

return {
	ActionTypes = ActionTypes,
	createAction = createAction,
	isKnownActionType = isKnownActionType,
	isValidAction = isValidAction,
	executeAction = executeAction,
}

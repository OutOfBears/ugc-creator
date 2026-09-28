local AttachmentUtils = require("../Utils/AttachmentUtils")
local MeshInfo = require("../MeshInfo")
local MeshUtils = require("../Utils/MeshUtils")
local MeshWidgetUtils = require("../Utils/MeshWidgetUtils")
local ModelInfo = require("../ModelInfo")

--[=[
	@class MeshEditActions

	The mesh-editing half of the action set. Both the client and the server run the same processor
	against their own copy of a creation, so a widget drag or a kitbash merge lands identically on
	each side.
]=]

export type ActionProcessor<T> = {
	isValidAction: (modelInfo: ModelInfo.ModelInfo, actionMetaData: T) -> boolean,
	executeAction: (modelInfo: ModelInfo.ModelInfo, actionMetaData: T) -> (),
}

export type UpdateWidgetPositionActionMetadata = {
	widgetName: string,

	newPosition: Vector3,

	newActiveControl: number?,
	newLinearProgress: number?,
}

export type UpdateAttachmentsPositionsActionMetadata = {}

export type MergeKitbashPieceActionMetadata = {
	targetMeshPartName: string,
	kitbashMeshId: string,
	kitbashTextureId: string,
	positionMarkerOffset: CFrame,
	scale: number,
	rotation: number,
	atlasSlot: number?,
	hasDrawnToAtlas: boolean,
}

export type UnmergeKitbashPieceActionMetadata = {
	targetMeshPartName: string,
	mergedFaceIds: { number },
	atlasSlot: number?,
}

export type UpdateDeformedEditableMeshesMetadata = {}

local function updateDeformedMeshes(meshInfo: MeshInfo.MeshInfo, deformedPartName: string)
	local partInfo: MeshInfo.MeshPartInfo = meshInfo:getMeshInfoByName(deformedPartName)

	local deformedPositions = MeshWidgetUtils.getDeformedMeshData(meshInfo, meshInfo:getAllWidgets(), deformedPartName)

	local updatedVertex = false
	assert(partInfo.cageInfo ~= nil, "Cage info is nil")
	local cageMesh = partInfo.cageInfo.cageEditableMesh
	for vertexId, vertexPos in deformedPositions do
		cageMesh:SetPosition(vertexId, vertexPos)
		updatedVertex = true
	end

	if updatedVertex then
		meshInfo:markMeshPartDirty(partInfo.meshPart)
	end
end

local function updateWidgetInfo(
	meshInfo: MeshInfo.MeshInfo,
	updatedWidget: MeshInfo.WidgetData,
	actionMetaData: UpdateWidgetPositionActionMetadata
)
	if actionMetaData.newActiveControl then
		updatedWidget.activeControl = updatedWidget.controls[actionMetaData.newActiveControl]
		if not updatedWidget.activeControl then
			warn("Active control not found for widget: ", updatedWidget.name)
		end
	end

	if actionMetaData.newLinearProgress and updatedWidget.activeControl then
		local activeLineControl = updatedWidget.activeControl :: MeshInfo.LineWidgetControl
		activeLineControl.linearProgress = actionMetaData.newLinearProgress
	end

	if actionMetaData.newPosition then
		updatedWidget.position = actionMetaData.newPosition
	end

	for _, deformedPartName in updatedWidget.deformsPartNames do
		updateDeformedMeshes(meshInfo, deformedPartName)
	end
end

local function checkMirrorWidget(
	meshInfo: MeshInfo.MeshInfo,
	updatedWidget: MeshInfo.WidgetData,
	actionMetaData: UpdateWidgetPositionActionMetadata
)
	if updatedWidget.mirroredWidget then
		local mirroredPosition = actionMetaData.newPosition * Vector3.new(-1, 1, 1)

		local mirroredActionMetaData: UpdateWidgetPositionActionMetadata = {
			widgetName = updatedWidget.mirroredWidget.name,
			newPosition = mirroredPosition,
			newActiveControl = actionMetaData.newActiveControl,
			newLinearProgress = actionMetaData.newLinearProgress,
		}

		updateWidgetInfo(meshInfo, updatedWidget.mirroredWidget, mirroredActionMetaData)
	end
end

--[=[
	@within MeshEditActions
	@prop UpdateWidgetPositionAction ActionProcessor<UpdateWidgetPositionActionMetadata>

	Moves one widget, redeforms every part it drives, and mirrors the move onto its twin.
]=]
local UpdateWidgetPositionAction: ActionProcessor<UpdateWidgetPositionActionMetadata> = {
	isValidAction = function(modelInfo, actionMetaData)
		local meshInfo: MeshInfo.MeshInfo = modelInfo:getMeshInfo()

		if not meshInfo:hasWidgetByName(actionMetaData.widgetName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData)
		local meshInfo: MeshInfo.MeshInfo = modelInfo:getMeshInfo()

		local updatedWidget: MeshInfo.WidgetData = meshInfo:getWidgetByName(actionMetaData.widgetName)
		updateWidgetInfo(meshInfo, updatedWidget, actionMetaData)

		checkMirrorWidget(meshInfo, updatedWidget, actionMetaData)
	end,
}

--[=[
	@within MeshEditActions
	@prop UpdateAttachmentsPositionsAction ActionProcessor<UpdateAttachmentsPositionsActionMetadata>

	Re-derives attachment positions from the deformed body and re-seats the accessories on them.
	It carries no metadata — it exists only so the client and server stay in step.
]=]
local UpdateAttachmentsPositionsAction: ActionProcessor<UpdateAttachmentsPositionsActionMetadata> = {
	isValidAction = function()
		return true
	end,
	executeAction = function(modelInfo)
		local model = modelInfo:getModel()

		AttachmentUtils.updateAccessoryAttachmentsPositions(model)

		AttachmentUtils.moveAccessoriesToAttachmentPoints(model)
	end,
}

--[=[
	@within MeshEditActions
	@prop MergeKitbashPieceAction ActionProcessor<MergeKitbashPieceActionMetadata>

	Merges a kitbash piece's geometry and texture into the target part.
]=]
local MergeKitbashPieceAction: ActionProcessor<MergeKitbashPieceActionMetadata> = {
	isValidAction = function(_modelInfo, actionMetaData)
		if not actionMetaData.targetMeshPartName or not actionMetaData.kitbashMeshId then
			return false
		end
		return true
	end,
	executeAction = function(modelInfo, actionMetaData)
		local meshInfo = modelInfo:getMeshInfo()
		local textureInfo = modelInfo:getTextureInfo()

		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		if not targetMeshPart then
			warn("Could not find target mesh part:", actionMetaData.targetMeshPartName)
			return
		end

		local editableMeshMap = meshInfo:getKitbashEditableMeshMap()
		local targetEditableMesh = editableMeshMap[targetMeshPart]

		local meshScaleFactorMap = meshInfo:getScaleFactorMap()
		local targetScaleFactor = meshScaleFactorMap[targetMeshPart]

		local baseTextureLayer = textureInfo:getBaseLayer(targetMeshPart)

		MeshUtils.mergeKitbashPiece({
			targetMeshPart = targetMeshPart,
			targetEditableMesh = targetEditableMesh,
			targetScaleFactor = targetScaleFactor,
			kitbashMeshId = actionMetaData.kitbashMeshId,
			kitbashTextureId = actionMetaData.kitbashTextureId,
			positionMarkerCFrame = targetMeshPart.CFrame:ToWorldSpace(actionMetaData.positionMarkerOffset),
			scale = actionMetaData.scale,
			rotation = actionMetaData.rotation,
			baseTextureLayer = baseTextureLayer,
			atlasSlot = actionMetaData.atlasSlot,
			hasDrawnToAtlas = actionMetaData.hasDrawnToAtlas,
		})

		if baseTextureLayer and not actionMetaData.hasDrawnToAtlas then
			textureInfo:updateOutputColorMap(targetMeshPart)
		end
	end,
}

--[=[
	@within MeshEditActions
	@prop UnmergeKitbashPieceAction ActionProcessor<UnmergeKitbashPieceActionMetadata>

	Removes a merged kitbash piece's faces, and clears its atlas slot when the piece is being
	deleted rather than re-placed.
]=]
local UnmergeKitbashPieceAction: ActionProcessor<UnmergeKitbashPieceActionMetadata> = {
	isValidAction = function(_modelInfo, actionMetaData)
		if not actionMetaData.targetMeshPartName or not actionMetaData.mergedFaceIds then
			return false
		end
		if #actionMetaData.mergedFaceIds == 0 then
			return false
		end
		return true
	end,
	executeAction = function(modelInfo, actionMetaData)
		local meshInfo = modelInfo:getMeshInfo()

		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		if not targetMeshPart then
			warn("Could not find target mesh part:", actionMetaData.targetMeshPartName)
			return
		end

		local editableMeshMap = meshInfo:getKitbashEditableMeshMap()
		local targetEditableMesh = editableMeshMap[targetMeshPart]

		for _, faceId in actionMetaData.mergedFaceIds do
			targetEditableMesh:RemoveFace(faceId)
		end
		targetEditableMesh:RemoveUnused()

		if actionMetaData.atlasSlot then
			local textureInfo = modelInfo:getTextureInfo()
			textureInfo:clearAtlasSlot(targetMeshPart, actionMetaData.atlasSlot)
			textureInfo:updateOutputColorMap(targetMeshPart)
		end
	end,
}

--[=[
	@within MeshEditActions
	@prop UpdateDeformedEditableMeshesAction ActionProcessor<UpdateDeformedEditableMeshesMetadata>

	Rebuilds every stale deformed mesh. It carries no metadata — it exists only so the client and
	server stay in step.
]=]
local UpdateDeformedEditableMeshesAction: ActionProcessor<UpdateDeformedEditableMeshesMetadata> = {
	isValidAction = function()
		return true
	end,
	executeAction = function(modelInfo)
		local meshInfo: MeshInfo.MeshInfo = modelInfo:getMeshInfo()
		meshInfo:updateDeformedEditableMeshes()
	end,
}

return {
	UpdateWidgetPositionAction = UpdateWidgetPositionAction,
	UpdateAttachmentsPositionsAction = UpdateAttachmentsPositionsAction,
	MergeKitbashPieceAction = MergeKitbashPieceAction,
	UnmergeKitbashPieceAction = UnmergeKitbashPieceAction,
	UpdateDeformedEditableMeshesAction = UpdateDeformedEditableMeshesAction,
}

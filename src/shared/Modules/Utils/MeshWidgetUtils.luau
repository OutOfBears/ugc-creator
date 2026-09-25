local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoundsConfig = require(ReplicatedStorage.Shared.Data.BoundsConfig)
local BoundsValidation = require("../BoundsValidation")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local GeometryUtil = require("./GeometryUtil")
local MeshInfo = require("../MeshInfo")
local MeshUtils = require("./MeshUtils")
local Sift = require(ReplicatedStorage.Packages.Sift)

--[=[
	@class MeshWidgetUtils

	Turns widget drags into cage vertex movements, and clamps how far each widget may travel so the
	deformed body still passes UGC bounds validation.
]=]

local CONTROL_ENDPOINT_KEYS = {
	"controlP1",
	"controlP2",
	"controlP3",
	"controlP4",
}

local function getMeshPartScaleFactor(partInfo: MeshInfo.MeshPartInfo): Vector3
	assert(partInfo.cageInfo ~= nil, "MeshInfo needs to have cageInfo for deformation")
	return partInfo.cageInfo.initialSize / partInfo.meshPart.Size
end

local function getOffsetMeshPartCFrame(partInfo: MeshInfo.MeshPartInfo, scaleFactor: Vector3, offset: Vector3): CFrame
	local meshPart = partInfo.meshPart
	local worldSpaceOffset = meshPart.CFrame:VectorToWorldSpace(offset * scaleFactor)
	local partRotationOnly = meshPart.CFrame - meshPart.CFrame.Position
	return partRotationOnly + (meshPart.Position - worldSpaceOffset)
end

local function validateOriginalSizeFromLimits(outOfBoundsData: BoundsValidation.OutOfBoundsData)
	local originalScaleFromMin = outOfBoundsData.originalSize / outOfBoundsData.minSize
	if originalScaleFromMin.X < 1 or originalScaleFromMin.Y < 1 or originalScaleFromMin.Z < 1 then
		error(
			string.format(
				"Combined original size of (%s) for all parts in %s is smaller than the minimum size of (%s). If you are seeing this error you need to adjust the mesh sizes of the base body for this experience.",
				tostring(outOfBoundsData.originalSize),
				outOfBoundsData.assetTypeEnum.Name,
				tostring(outOfBoundsData.minSize)
			)
		)
	end
	local originalScaleFromMax = outOfBoundsData.maxSize / outOfBoundsData.originalSize
	if originalScaleFromMax.X < 1 or originalScaleFromMax.Y < 1 or originalScaleFromMax.Z < 1 then
		error(
			string.format(
				"Combined original size of (%s) for all parts in %s is larger than the maximum size of (%s). If you are seeing this error you need to adjust the mesh sizes of the base body for this experience.",
				tostring(outOfBoundsData.originalSize),
				outOfBoundsData.assetTypeEnum.Name,
				tostring(outOfBoundsData.maxSize)
			)
		)
	end
end

local function getScaleFactorFromVectorComponent(outOfBoundsData: BoundsValidation.OutOfBoundsData, key: string): number
	local originalSizeComp = outOfBoundsData.originalSize[key]
	local currentSizeComp = outOfBoundsData.size[key]
	local minSizeComp = outOfBoundsData.minSize[key]
	local maxSizeComp = outOfBoundsData.maxSize[key]

	if currentSizeComp >= minSizeComp and currentSizeComp <= maxSizeComp then
		return 1
	end

	local scaleFromOriginal = currentSizeComp / originalSizeComp

	local diffFromOriginal, diffFromLimit

	if scaleFromOriginal < 1 then
		diffFromOriginal = (originalSizeComp - currentSizeComp) / originalSizeComp
		diffFromLimit = (originalSizeComp - minSizeComp) / originalSizeComp
	else
		diffFromOriginal = (currentSizeComp - originalSizeComp) / originalSizeComp
		diffFromLimit = (maxSizeComp - originalSizeComp) / originalSizeComp
	end

	return diffFromLimit / diffFromOriginal
end

local function getWidgetScaleFactor(outOfBoundsDatas: { BoundsValidation.OutOfBoundsData }): number
	local scaleFactorX = math.huge
	local scaleFactorY = math.huge
	local scaleFactorZ = math.huge

	for _, outOfBoundsData in outOfBoundsDatas do
		validateOriginalSizeFromLimits(outOfBoundsData)

		scaleFactorX = math.min(scaleFactorX, getScaleFactorFromVectorComponent(outOfBoundsData, "X"))
		scaleFactorY = math.min(scaleFactorY, getScaleFactorFromVectorComponent(outOfBoundsData, "Y"))
		scaleFactorZ = math.min(scaleFactorZ, getScaleFactorFromVectorComponent(outOfBoundsData, "Z"))
	end

	return math.min(scaleFactorX, math.min(scaleFactorY, scaleFactorZ))
end

local function getNewControlPosition(currentPosition: Vector3, startPosition: Vector3, scaleFactor: number): Vector3
	local direction = currentPosition - startPosition
	return startPosition + (direction.Unit * (direction.Magnitude * scaleFactor * BoundsConfig.boundsPadding))
end

local function deformSingleVertex(
	vertexPos: Vector3,
	widgetData: MeshInfo.WidgetData,
	startPosition: Vector3,
	currentPosition: Vector3
): Vector3
	if widgetData.widgetType == CreationConfig.widgetTypes.sphere then
		local widgetOffset = currentPosition - startPosition
		local distance = (vertexPos - startPosition).Magnitude
		if distance <= widgetData.radius then
			local falloff = 1 - math.clamp(distance / widgetData.radius, 0, 1)

			local newDeformedPos = vertexPos + widgetOffset * falloff * 0.5
			return newDeformedPos
		end
		return vertexPos
	end

	local activeLineControl = widgetData.activeControl :: MeshInfo.LineWidgetControl?
	if not activeLineControl then
		return vertexPos
	end

	if widgetData.widgetType == CreationConfig.widgetTypes.growShrink then
		local offset = vertexPos - startPosition
		local distance = offset.Magnitude
		if distance <= widgetData.radius then
			local falloff = 1 - math.clamp(distance / widgetData.radius, 0, 1)

			local newDeformedPos = vertexPos
				+ offset * falloff * (activeLineControl.linearProgress - activeLineControl.startLinearProgress)
			return newDeformedPos
		end
	elseif widgetData.widgetType == CreationConfig.widgetTypes.axisStretch then
		assert(widgetData.meshSpaceAxisStart ~= nil, "Axis stretch widget has no meshSpaceAxisStart")

		local axisDirection = widgetData.meshSpaceAxisStart.Direction
		local offset = vertexPos - widgetData.meshSpaceAxisStart.Origin
		local axisProjection = offset:Dot(axisDirection) * axisDirection.Unit
		local distance = offset.Magnitude
		if distance <= widgetData.radius then
			local falloff = 1 - math.clamp(distance / widgetData.radius, 0, 1)

			local newDeformedPos = vertexPos
				+ axisProjection
					* falloff
					* (activeLineControl.linearProgress - activeLineControl.startLinearProgress)
			return newDeformedPos
		end
	elseif widgetData.widgetType == CreationConfig.widgetTypes.cylinder then
		assert(widgetData.meshSpaceAxisStart ~= nil, "Cylinder widget has no meshSpaceAxisStart")

		local closestPoint = widgetData.meshSpaceAxisStart:ClosestPoint(vertexPos)
		local offset = vertexPos - closestPoint
		local distanceToAxis = offset.Magnitude
		if distanceToAxis <= widgetData.radius then
			local falloff = 1 - math.clamp(distanceToAxis / widgetData.radius, 0, 1)

			local newDeformedPos = vertexPos
				+ offset * falloff * (activeLineControl.linearProgress - activeLineControl.startLinearProgress)
			return newDeformedPos
		end
	elseif widgetData.widgetType == CreationConfig.widgetTypes.muscle then
		if widgetData.meshSpaceAxisStart == nil then
			error("Muscle widget has no meshSpaceAxisStart")
		end

		local closestPointOnSegment, t = GeometryUtil.closestPointOnSegment(
			vertexPos,
			widgetData.meshSpaceAxisStart.Origin,
			widgetData.meshSpaceAxisEnd :: Vector3
		)
		if t < 0 or t > 1 then
			t = 0
		end
		local distanceFromCenter = math.abs(0.5 - math.abs(t - 0.5)) * 2
		local offset = vertexPos - closestPointOnSegment
		local distanceToAxis = offset.Magnitude
		local falloff = 1 - math.clamp(distanceToAxis / widgetData.radius, 0, 1)
		falloff = falloff * distanceFromCenter

		local newDeformedPos = vertexPos
			+ offset * falloff * (activeLineControl.linearProgress - activeLineControl.startLinearProgress) * 2
		return newDeformedPos
	else
		print("No widget type found for widgetData.widgetType: ", widgetData.widgetType)
		return vertexPos
	end

	return vertexPos
end

--[=[
	@within MeshWidgetUtils
	@param widgetData MeshInfo.WidgetData -- the widget to test
	@param partName string -- the MeshPart name to test against
	@return boolean -- true if moving this widget deforms that part
]=]
local function widgetDeformsPart(widgetData: MeshInfo.WidgetData, partName: string): boolean
	for _, deformedPartName in widgetData.deformsPartNames do
		if deformedPartName == partName then
			return true
		end
	end
	return false
end

--[=[
	@within MeshWidgetUtils
	@param meshInfo MeshInfo.MeshInfo -- the creation's mesh data
	@param widgets { MeshInfo.WidgetData } -- the widgets to apply
	@param deformedPartName string -- the MeshPart whose cage is being deformed
	@return { [number]: Vector3 } -- cage vertex id to deformed position

	Each widget contributes the difference it makes on its own, so overlapping widgets accumulate
	rather than overwrite one another.
]=]
local function getDeformedMeshData(
	meshInfo: MeshInfo.MeshInfo,
	widgets: { [any]: MeshInfo.WidgetData },
	deformedPartName: string
): { [number]: Vector3 }
	local partInfo: MeshInfo.MeshPartInfo = meshInfo:getMeshInfoByName(deformedPartName)

	assert(partInfo.cageInfo ~= nil, "MeshInfo needs to have cageInfo for deformation")

	local initialCageVertexPositions = partInfo.cageInfo.initialVertexPositionsMap

	local deformedPositions = {}

	for _, widgetData: MeshInfo.WidgetData in widgets do
		if widgetData.startPosition == widgetData.position then
			continue
		end

		if not widgetDeformsPart(widgetData, deformedPartName) then
			continue
		end

		local startPosition = widgetData.startPosition
		local currentPosition = widgetData.position
		if widgetData.meshPart.Name ~= deformedPartName then
			local worldStartPosition = widgetData.meshPart.CFrame:PointToWorldSpace(startPosition)
			startPosition = partInfo.meshPart.CFrame:PointToObjectSpace(worldStartPosition)

			local worldCurrentPosition = widgetData.meshPart.CFrame:PointToWorldSpace(currentPosition)
			currentPosition = partInfo.meshPart.CFrame:PointToObjectSpace(worldCurrentPosition)
		end

		for vertexId, vertexPos in initialCageVertexPositions do
			local currentDeformedPos = deformedPositions[vertexId]
			if currentDeformedPos == nil then
				currentDeformedPos = vertexPos
			end

			local cageSpaceVertexPos = partInfo.cageInfo.cageOrigin * vertexPos
			local deformedPos = deformSingleVertex(cageSpaceVertexPos, widgetData, startPosition, currentPosition)

			local diff: Vector3 = deformedPos - cageSpaceVertexPos
			deformedPositions[vertexId] = currentDeformedPos + diff
		end
	end

	return deformedPositions
end

local function getInitialSimMeshInfo(meshInfo: MeshInfo.MeshInfo): BoundsValidation.SimMeshInfos
	local initialMeshInfo = {} :: BoundsValidation.SimMeshInfos
	for part, partInfo: MeshInfo.MeshPartInfo in meshInfo:getModelMeshInfo() do
		if not partInfo.cageInfo then
			continue
		end

		local scaleFactor = getMeshPartScaleFactor(partInfo)
		local initialVertexPositions = partInfo.cageInfo.initialVertexPositionsMap
		local scaledVertices = {}
		for vertexId, vertexPos in initialVertexPositions do
			scaledVertices[vertexId] = vertexPos / scaleFactor
		end

		initialMeshInfo[part.Name] = {
			Verts = scaledVertices,
			CFrame = partInfo.meshPart.CFrame,
		} :: BoundsValidation.SimMeshInfo
	end

	return initialMeshInfo
end

local function getDeformedSimMeshInfo(
	meshInfo: MeshInfo.MeshInfo,
	widget: MeshInfo.WidgetData
): BoundsValidation.SimMeshInfos
	local deformedMeshInfo = {} :: BoundsValidation.SimMeshInfos
	for _, deformedPartName in widget.deformsPartNames do
		local partInfo: MeshInfo.MeshPartInfo = meshInfo:getMeshInfoByName(deformedPartName)

		local widgets = { widget }
		if widget.mirroredWidget then
			table.insert(widgets, widget.mirroredWidget)
		end

		local deformedPositions = getDeformedMeshData(meshInfo, widgets, deformedPartName)
		local min, max = MeshUtils.getVertexBounds(deformedPositions)

		local center = (min + max) / 2
		local scaleFactor = getMeshPartScaleFactor(partInfo)
		local newCFrame = getOffsetMeshPartCFrame(partInfo, scaleFactor, -center)
		for vertexId, vertexPos in deformedPositions do
			deformedPositions[vertexId] = (vertexPos - center) / scaleFactor
		end

		if not next(deformedPositions) then
			continue
		end

		deformedMeshInfo[deformedPartName] = {
			Verts = deformedPositions,
			CFrame = newCFrame,
		} :: BoundsValidation.SimMeshInfo
	end

	return deformedMeshInfo
end

local function combineSimMeshInfo(
	meshInfo: MeshInfo.MeshInfo,
	initialMeshInfo: BoundsValidation.SimMeshInfos,
	deformedMeshInfo: BoundsValidation.SimMeshInfos
)
	for part in meshInfo:getModelMeshInfo() do
		local initialInfoForPart: BoundsValidation.SimMeshInfo = initialMeshInfo[part.Name]
		local deformedInfoForPart: BoundsValidation.SimMeshInfo = deformedMeshInfo[part.Name]

		if not deformedInfoForPart and initialInfoForPart then
			deformedMeshInfo[part.Name] = initialInfoForPart
		end
	end
end

local function copyWidgetData(widgetData: MeshInfo.WidgetData, newPosition: Vector3): MeshInfo.WidgetData
	local oldMirroredWidget = widgetData.mirroredWidget
	widgetData.mirroredWidget = nil
	local widgetDataCopy = Sift.Dictionary.copyDeep(widgetData)
	widgetDataCopy.position = newPosition

	if oldMirroredWidget then
		widgetDataCopy.mirroredWidget = Sift.Dictionary.copyDeep(oldMirroredWidget)
		widgetDataCopy.mirroredWidget.position = widgetDataCopy.position * Vector3.new(-1, 1, 1)
	end

	widgetData.mirroredWidget = oldMirroredWidget

	return widgetDataCopy
end

local function copyWidgetControl(widgetDataCopy: MeshInfo.WidgetData, widgetControl: MeshInfo.WidgetControl)
	local widgetControlCopy = {} :: any
	for key, value in widgetControl :: { [any]: any } do
		widgetControlCopy[key] = value
	end

	if widgetControlCopy.controlType == "Line" then
		local lineDirection = (widgetControlCopy.controlP2 - widgetControlCopy.controlP1)
		local closestLinePoint = GeometryUtil.closestPointOnSegment(
			widgetDataCopy.position,
			widgetControlCopy.controlP1,
			widgetControlCopy.controlP2
		)
		local controlLinearProgress = (closestLinePoint - widgetControlCopy.controlP1).Magnitude
			/ lineDirection.Magnitude

		widgetControlCopy.linearProgress = controlLinearProgress
		widgetDataCopy.activeControl = widgetControlCopy
	end
end

local function simulateWidgetMoved(
	meshInfo: MeshInfo.MeshInfo,
	widgetData: MeshInfo.WidgetData,
	widgetControl: MeshInfo.WidgetControl,
	newPosition: Vector3
): (BoundsValidation.SimMeshInfos, BoundsValidation.SimMeshInfos)
	local widgetDataCopy = copyWidgetData(widgetData, newPosition)

	copyWidgetControl(widgetDataCopy, widgetControl)
	if widgetDataCopy.mirroredWidget then
		copyWidgetControl(widgetDataCopy.mirroredWidget, widgetControl)
	end

	local initialMeshInfo = getInitialSimMeshInfo(meshInfo)
	local deformedMeshInfo = getDeformedSimMeshInfo(meshInfo, widgetDataCopy)
	combineSimMeshInfo(meshInfo, initialMeshInfo, deformedMeshInfo)

	return initialMeshInfo, deformedMeshInfo
end

local function getFixedControlPositions(
	meshInfo: MeshInfo.MeshInfo,
	widgetControl: MeshInfo.WidgetControl,
	widgetData: MeshInfo.WidgetData
): { [string]: Vector3 }
	local fixedControlPositions = {}
	for _, key in CONTROL_ENDPOINT_KEYS do
		local controlPosition = (widgetControl :: any)[key]
		if controlPosition then
			local initialMeshInfo, deformedMeshInfo =
				simulateWidgetMoved(meshInfo, widgetData, widgetControl, controlPosition)
			local outOfBoundsDatas =
				BoundsValidation.validateBounds(initialMeshInfo, deformedMeshInfo, widgetData.deformsPartNames)

			if outOfBoundsDatas and #outOfBoundsDatas > 0 then
				local scaleFactor = getWidgetScaleFactor(outOfBoundsDatas)
				fixedControlPositions[key] =
					getNewControlPosition(controlPosition, widgetData.startPosition, scaleFactor)
			end
		end
	end
	return fixedControlPositions
end

local function updateWidgetControl(
	widgetControl: MeshInfo.WidgetControl,
	widgetData: MeshInfo.WidgetData,
	fixedControlPositions: { [string]: Vector3 }
)
	for key, controlPosition in fixedControlPositions do
		(widgetControl :: any)[key] = controlPosition
	end

	if widgetControl.controlType == "Line" then
		local oldStartLinearProgress = widgetControl.startLinearProgress
		local lineDirection = (widgetControl.controlP2 - widgetControl.controlP1)
		widgetControl.startLinearProgress = (widgetData.startPosition - widgetControl.controlP1).Magnitude
			/ lineDirection.Magnitude
		widgetControl.linearProgress = widgetControl.startLinearProgress
		widgetData.radius = widgetData.radius
			* (1 - math.abs(widgetControl.startLinearProgress - oldStartLinearProgress))
			* BoundsConfig.boundsPadding
	end
end

--[=[
	@within MeshWidgetUtils
	@param meshInfo MeshInfo.MeshInfo -- the creation's mesh data

	Pulls in every widget control endpoint that would push the body outside the UGC size limits, so
	no drag the player can make produces an invalid creation.
]=]
local function fixupWidgets(meshInfo: MeshInfo.MeshInfo)
	for _, widgetData in meshInfo:getAllWidgets() do
		for _, widgetControl in widgetData.controls do
			updateWidgetControl(
				widgetControl,
				widgetData,
				getFixedControlPositions(meshInfo, widgetControl, widgetData)
			)
		end
	end
end

return {
	widgetDeformsPart = widgetDeformsPart,
	getDeformedMeshData = getDeformedMeshData,
	fixupWidgets = fixupWidgets,
}

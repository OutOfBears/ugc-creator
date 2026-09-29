--[=[
	@class ImageEditActions

	The paint-side action processors, run identically on the client for preview and on the server
	for the authoritative model. Each entry validates its metadata, then applies it to the
	creation's EditableImages.
]=]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AtlasUtil = require("../Utils/AtlasUtil")
local BrushTips = require(ReplicatedStorage.Shared.Data.BrushTips)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local GeometryUtil = require("../Utils/GeometryUtil")
local ModelInfo = require("../ModelInfo")
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)
local TextureInfo = require("../TextureInfo")
local TextureUtils = require("../Utils/TextureUtils")

export type ImageEditAction = {
	isValidAction: (modelInfo: any, actionMetaData: any) -> boolean,
	executeAction: (modelInfo: any, actionMetaData: any) -> any,
}

export type RecolorActionMetadata = {
	color: Color3,
	targetMeshPartName: string,
	opacity: number?,
	isReflectiveMode: boolean?,
}

export type RecolorRegionActionMetadata = {
	color: Color3,
	regionName: string,
	opacity: number?,
	isReflectiveMode: boolean?,
}

export type RecolorSectionActionMetadata = {
	sectionName: string,
	color: Color3,
	opacity: number?,
}

export type SelectVariantActionMetadata = {
	groupName: string,
	optionIndex: number,
}

export type ApplyPBRToRegionActionMetadata = {
	regionName: string,
	isReflectiveMode: boolean?,
}

export type BrushStrokeActionMetadata = {
	targetMeshPartName: string,
	paintLayerId: string,
	brushSize: number,
	brushColor: Color3,
	brushTransparency: number,
	drawPositions: { Vector2 },
}

export type ClearBrushActionMetadata = {
	targetMeshPartName: string,
	paintLayerId: string,
}

export type LinearBrushActionMetadata = {
	targetMeshPartName: string,
	paintLayerId: string,
	brushSize: number,
	brushColor: Color3,
	brushTransparency: number,
	tipId: string?,
	drawPositions: { Vector2 },
}

export type StickerActionMetadata = {
	targetMeshPartName: string,
	stickerLayerNumber: number,
	paintLayerId: string,
	textureId: string,

	position: Vector2,
	rotation: number,
	scale: number,
}

export type RemoveStickerActionMetadata = {
	targetMeshPartName: string,
	stickerLayerNumber: number,
}

export type ProjectedStickerActionMetadata = {
	targetMeshPartName: string,
	textureId: string,
	stickerLayerNumber: number,
	paintLayerId: string,
	clearTexture: boolean,

	rotation: number,
	scale: number,
	direction: Vector3,
	position: Vector3,
}

export type TiledStickerActionMetadata = {
	targetMeshPartName: string,
	stickerLayerNumber: number,
	paintLayerId: string,
	textureId: string,

	texturePosition: Vector2,
	rotation: number,
	scale: number,
	tilePadding: number,

	regionName: string,
}

export type ClearActionMetadata = {
	targetMeshPartName: string,
}

export type ClearRegionActionMetadata = {
	regionName: string,
}

export type ProjectionBrushActionMetadata = {
	referenceMeshPartName: string,
	paintLayerId: string,
	brushColor: Color3,
	brushSize: number,
	colorBlendType: Enum.ImageCombineType,
	alphaBlendType: Enum.ImageAlphaType,
	cameraCFrame: CFrame,
	drawPositions: { Vector2 },
	isReflectiveMode: boolean?,
	brushTransparency: number?,
	tipId: string?,
	intermediateEditableImageBuffer: buffer,
	cachedTargetImageBuffer: buffer,
}

local ImageEditActions = {}

-- An atlas creation paints into the top-left cell of its atlas, not the whole image.
local function getSizeForTextureBuffer(modelInfo, colorMap: EditableImage): Vector2
	local atlasLayout = modelInfo:getAtlasLayout()
	if not atlasLayout then
		return colorMap.Size
	end

	return select(2, AtlasUtil.toPixels(atlasLayout.base, colorMap.Size))
end

local function isKnownTipId(tipId: any): boolean
	return tipId == nil or (typeof(tipId) == "string" and BrushTips.tips[tipId] ~= nil)
end

local function getPaintLayerImage(modelInfo, meshPartName: string?, paintLayerId: any): EditableImage?
	if typeof(paintLayerId) ~= "string" then
		return nil
	end

	local meshPart = modelInfo:getMeshPartByName(meshPartName)
	if not meshPart then
		return nil
	end

	return modelInfo:getTextureInfo():getPaintLayerImage(meshPart, paintLayerId)
end

local function isValidPaintLayer(modelInfo, paintLayerId: any): boolean
	return typeof(paintLayerId) == "string" and modelInfo:getTextureInfo():getPaintLayer(paintLayerId) ~= nil
end

local function getUniqueEditableImages(
	modelInfo: ModelInfo.ModelInfo,
	textureInfo: TextureInfo.TextureInfo,
	meshPartNames: { string }
)
	local uniqueEditableImages = {}

	for _, meshPartName in pairs(meshPartNames) do
		local meshPart = modelInfo:getMeshPartByName(meshPartName)
		local colorMap = textureInfo:getOrCreateLayer(meshPart, CreationConfig.layerNames.fabricFill)

		uniqueEditableImages[colorMap] = meshPartName
	end

	return uniqueEditableImages
end

local function isAllowedSticker(textureId: string?): boolean
	if not textureId then
		return false
	end

	for _, sticker in Stickers do
		if textureId == sticker.textureId then
			return true
		end
	end

	return false
end

--[=[
	@within ImageEditActions
	@prop RecolorAction ImageEditAction

	Floods one mesh part's fabric fill layer with a color.
]=]
ImageEditActions.RecolorAction = {
	isValidAction = function(modelInfo, actionMetaData: RecolorActionMetadata)
		if actionMetaData.color == nil then
			return false
		end

		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: RecolorActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local colorMap: EditableImage =
			textureInfo:getOrCreateLayer(targetMeshPart, CreationConfig.layerNames.fabricFill)

		colorMap:DrawRectangle(
			Vector2.new(0, 0),
			getSizeForTextureBuffer(modelInfo, colorMap),
			actionMetaData.color,
			1 - actionMetaData.opacity,
			Enum.ImageCombineType.Overwrite
		)

		TextureUtils.applyPBRMaps(textureInfo, targetMeshPart, actionMetaData.isReflectiveMode)
	end,
}

--[=[
	@within ImageEditActions
	@prop RecolorSectionAction ImageEditAction

	Records the chosen color and opacity for one named layer section, then rebakes the atlas cell that
	section is drawn into. Accessory sections are keyed `"<slot>.<section>"`.
]=]
ImageEditActions.RecolorSectionAction = {
	isValidAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: RecolorSectionActionMetadata)
		if typeof(actionMetaData.color) ~= "Color3" or typeof(actionMetaData.sectionName) ~= "string" then
			return false
		end
		if actionMetaData.opacity ~= nil and typeof(actionMetaData.opacity) ~= "number" then
			return false
		end

		local catalog, _, name = modelInfo:resolveColorKey(actionMetaData.sectionName)
		if not catalog then
			return false
		end

		if table.find(catalog.sortOrder, name) then
			return true
		end
		for _, group in catalog.variantGroups do
			if group.name == name then
				return true
			end
		end

		return false
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: RecolorSectionActionMetadata)
		local opacity = if actionMetaData.opacity ~= nil then actionMetaData.opacity else 1
		modelInfo:saveSectionColor(actionMetaData.sectionName, actionMetaData.color, 1 - opacity)

		local _, cell = modelInfo:resolveColorKey(actionMetaData.sectionName)
		modelInfo:bakeLayerColors(cell)
	end,
}

--[=[
	@within ImageEditActions
	@prop SelectVariantAction ImageEditAction

	Records which option of a variant group (e.g. which mouth) is selected, then rebakes the cell
	that group is drawn into. Accessory groups are keyed `"<slot>.<group>"`.
]=]
ImageEditActions.SelectVariantAction = {
	isValidAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: SelectVariantActionMetadata)
		local optionIndex = actionMetaData.optionIndex
		if typeof(actionMetaData.groupName) ~= "string" or typeof(optionIndex) ~= "number" then
			return false
		end
		if optionIndex % 1 ~= 0 then
			return false
		end

		local catalog, _, name = modelInfo:resolveColorKey(actionMetaData.groupName)
		if not catalog then
			return false
		end

		for _, group in catalog.variantGroups do
			if group.name == name then
				return optionIndex >= 1 and optionIndex <= #group.options
			end
		end

		return false
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: SelectVariantActionMetadata)
		modelInfo:saveVariantSelection(actionMetaData.groupName, actionMetaData.optionIndex)

		local _, cell = modelInfo:resolveColorKey(actionMetaData.groupName)
		modelInfo:bakeLayerColors(cell)
	end,
}

--[=[
	@within ImageEditActions
	@prop RecolorRegionAction ImageEditAction

	Colors every mesh part of a named region, stencilled by the region's mask where it has one.
]=]
ImageEditActions.RecolorRegionAction = {
	isValidAction = function(modelInfo, actionMetaData: RecolorRegionActionMetadata)
		if actionMetaData.color == nil or actionMetaData.regionName == nil then
			return false
		end

		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

		if not textureInfo:hasRegion(actionMetaData.regionName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: RecolorRegionActionMetadata)
		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()
		local region: TextureInfo.Region = textureInfo:getRegion(actionMetaData.regionName)

		local uniqueEditableImages = getUniqueEditableImages(modelInfo, textureInfo, region.meshPartNames)

		local opacity = if actionMetaData.opacity then actionMetaData.opacity else 1

		if region.regionBuffer then
			assert(region.regionColor, "Region color must be defined if regionBuffer is defined")

			for colorMap: EditableImage, _targetMeshPartName in uniqueEditableImages do
				local textureSize = getSizeForTextureBuffer(modelInfo, colorMap)
				local currentPixelsBuffer = colorMap:ReadPixelsBuffer(Vector2.zero, textureSize)
				local regionPixelsBuffer = region.regionBuffer
				local fillAlphaByte = math.floor(255 * opacity)
				fillAlphaByte = math.clamp(fillAlphaByte, 0, 255)

				if buffer.len(regionPixelsBuffer) == buffer.len(currentPixelsBuffer) then
					TextureUtils.performRegionColor(
						currentPixelsBuffer,
						region,
						actionMetaData.color,
						colorMap,
						textureSize,
						fillAlphaByte
					)
				else
					TextureUtils.writeBufferForLargerRegionMap(
						textureSize,
						regionPixelsBuffer,
						currentPixelsBuffer,
						region.regionColor,
						actionMetaData.color,
						fillAlphaByte
					)
				end

				colorMap:WritePixelsBuffer(Vector2.zero, textureSize, currentPixelsBuffer)
			end

			TextureUtils.applyPBRToRegion(modelInfo, textureInfo, region, actionMetaData.isReflectiveMode)
		else
			for colorMap, _ in uniqueEditableImages do
				local textureSize = getSizeForTextureBuffer(modelInfo, colorMap)
				colorMap:DrawRectangle(
					Vector2.new(0, 0),
					textureSize,
					actionMetaData.color,
					1 - opacity,
					Enum.ImageCombineType.Overwrite
				)
			end
		end

		TextureUtils.applyPBRToRegion(modelInfo, textureInfo, region, actionMetaData.isReflectiveMode)
	end,
}

--[=[
	@within ImageEditActions
	@prop ApplyPBRToRegionAction ImageEditAction

	Rewrites a region's metalness and roughness maps without touching its color.
]=]
ImageEditActions.ApplyPBRToRegionAction = {
	isValidAction = function(modelInfo, actionMetaData: ApplyPBRToRegionActionMetadata)
		if actionMetaData.regionName == nil then
			return false
		end

		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

		return textureInfo:hasRegion(actionMetaData.regionName)
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: ApplyPBRToRegionActionMetadata)
		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()
		local region: TextureInfo.Region = textureInfo:getRegion(actionMetaData.regionName)

		TextureUtils.applyPBRToRegion(modelInfo, textureInfo, region, actionMetaData.isReflectiveMode)
	end,
}

--[=[
	@within ImageEditActions
	@prop BrushStrokeAction ImageEditAction

	Stamps a circle at each sampled position on the brush layer.
]=]
ImageEditActions.BrushStrokeAction = {
	isValidAction = function(modelInfo, actionMetaData: BrushStrokeActionMetadata)
		if
			not actionMetaData.brushSize
			or not actionMetaData.brushColor
			or not actionMetaData.brushTransparency
			or not actionMetaData.drawPositions
		then
			return false
		end

		if
			actionMetaData.brushSize < CreationConfig.minBrushSize
			or actionMetaData.brushSize > CreationConfig.maxBrushSize
		then
			return false
		end

		if actionMetaData.brushTransparency < 0 or actionMetaData.brushTransparency > 1 then
			return false
		end

		if not getPaintLayerImage(modelInfo, actionMetaData.targetMeshPartName, actionMetaData.paintLayerId) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: BrushStrokeActionMetadata)
		local textureInfo = modelInfo:getTextureInfo()
		local brushLayer: EditableImage = getPaintLayerImage(
			modelInfo,
			actionMetaData.targetMeshPartName,
			actionMetaData.paintLayerId
		) :: EditableImage

		local brushSize = actionMetaData.brushSize
		local color = actionMetaData.brushColor
		local transparency = actionMetaData.brushTransparency

		local prevBrushBuffer = brushLayer:ReadPixelsBuffer(Vector2.zero, brushLayer.Size)

		for _, drawPosition in pairs(actionMetaData.drawPositions) do
			brushLayer:DrawCircle(drawPosition, brushSize, color, transparency, Enum.ImageCombineType.BlendSourceOver)
		end

		local currentRegionMap = textureInfo:getMeshPartRegion(actionMetaData.targetMeshPartName)
		TextureUtils.performRegionStencil(currentRegionMap, prevBrushBuffer, brushLayer)
	end,
}

--[=[
	@within ImageEditActions
	@prop ClearBrushAction ImageEditAction

	Wipes one mesh part's brush layer and resets its PBR maps.
]=]
ImageEditActions.ClearBrushAction = {
	isValidAction = function(modelInfo, actionMetaData: ClearBrushActionMetadata)
		if not getPaintLayerImage(modelInfo, actionMetaData.targetMeshPartName, actionMetaData.paintLayerId) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: ClearBrushActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local brushLayer: EditableImage = getPaintLayerImage(
			modelInfo,
			actionMetaData.targetMeshPartName,
			actionMetaData.paintLayerId
		) :: EditableImage

		TextureUtils.clear(brushLayer)
		TextureUtils.clearPBR(textureInfo, targetMeshPart)
	end,
}

--[=[
	@within ImageEditActions
	@prop LinearBrushAction ImageEditAction

	Paints a continuous stroke by interpolating circles between the sampled positions.
]=]
ImageEditActions.LinearBrushAction = {
	isValidAction = function(modelInfo, actionMetaData: LinearBrushActionMetadata)
		if not actionMetaData.brushSize or not actionMetaData.drawPositions then
			return false
		end

		if
			actionMetaData.brushSize < CreationConfig.minBrushSize
			or actionMetaData.brushSize > CreationConfig.maxBrushSize
		then
			return false
		end

		if not getPaintLayerImage(modelInfo, actionMetaData.targetMeshPartName, actionMetaData.paintLayerId) then
			return false
		end

		return isKnownTipId(actionMetaData.tipId)
	end,
	executeAction = function(modelInfo, actionMetaData: LinearBrushActionMetadata)
		local textureInfo = modelInfo:getTextureInfo()
		local brushLayer: EditableImage = getPaintLayerImage(
			modelInfo,
			actionMetaData.targetMeshPartName,
			actionMetaData.paintLayerId
		) :: EditableImage

		local rectPosition, rectSize =
			TextureUtils.getStrokeRect(actionMetaData.drawPositions, actionMetaData.brushSize, brushLayer.Size)
		if rectSize.X <= 0 or rectSize.Y <= 0 then
			return
		end

		local prevBrushBuffer = brushLayer:ReadPixelsBuffer(rectPosition, rectSize)

		local isErasing = actionMetaData.brushTransparency >= 1
		local stamp = if isErasing
			then nil
			else TextureUtils.createLinearStamp(
				actionMetaData.brushSize,
				actionMetaData.brushColor,
				actionMetaData.tipId
			)

		local prevDrawPosition = #actionMetaData.drawPositions > 0 and actionMetaData.drawPositions[1] or nil
		for _, drawPosition in pairs(actionMetaData.drawPositions) do
			if stamp then
				TextureUtils.stampBetweenPoints(
					prevDrawPosition,
					drawPosition,
					actionMetaData.brushSize,
					actionMetaData.tipId,
					stamp,
					brushLayer
				)
			else
				TextureUtils.drawCircleBetweenPoints(
					prevDrawPosition,
					drawPosition,
					actionMetaData.brushSize,
					actionMetaData.brushColor,
					actionMetaData.brushTransparency,
					brushLayer
				)
			end
			prevDrawPosition = drawPosition
		end

		if stamp then
			stamp:Destroy()
		end

		local currentRegionMap = textureInfo:getMeshPartRegion(actionMetaData.targetMeshPartName)
		TextureUtils.performRegionStencil(currentRegionMap, prevBrushBuffer, brushLayer, rectPosition, rectSize)
	end,
}

--[=[
	@within ImageEditActions
	@prop StickerAction ImageEditAction

	Stamps a single sticker onto its own layer in texture space.
]=]
ImageEditActions.StickerAction = {
	isValidAction = function(modelInfo, actionMetaData: StickerActionMetadata)
		if not actionMetaData.position or not actionMetaData.rotation or not actionMetaData.scale then
			return false
		end

		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		if actionMetaData.stickerLayerNumber < 1 then
			return false
		end

		if actionMetaData.stickerLayerNumber > CreationConfig.maxStickerLayers then
			return false
		end

		if not isValidPaintLayer(modelInfo, actionMetaData.paintLayerId) then
			return false
		end

		if not isAllowedSticker(actionMetaData.textureId) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: StickerActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local stickerLayer: EditableImage, didCreateLayer: boolean = textureInfo:getOrCreateLayer(
			targetMeshPart,
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber
		)
		textureInfo:setStickerPaintLayer(
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber,
			actionMetaData.paintLayerId
		)

		if not didCreateLayer then
			TextureUtils.clear(stickerLayer)
		end

		local source = textureInfo:getOrCreateEditableImageByTextureId(actionMetaData.textureId)
		local drawnSize = math.max(source.Size.X, source.Size.Y) * actionMetaData.scale * 0.5
		local stickerTexture = textureInfo:getStickerImage(actionMetaData.textureId, drawnSize)
		local drawScale = drawnSize / math.max(stickerTexture.Size.X, stickerTexture.Size.Y)
		local currentRegionMap = textureInfo:getMeshPartRegion(actionMetaData.targetMeshPartName)

		if currentRegionMap == nil then
			local scaleVector = Vector2.one * drawScale
			stickerLayer:DrawImageTransformed(
				actionMetaData.position,
				scaleVector,
				actionMetaData.rotation,
				stickerTexture,
				{
					CombineType = Enum.ImageCombineType.Overwrite,
					SamplingMode = Enum.ResamplerMode.Default,
				}
			)
		else
			local prevStickerBuffer = stickerLayer:ReadPixelsBuffer(Vector2.zero, stickerLayer.Size)

			local scaleVector = Vector2.one * drawScale
			stickerLayer:DrawImageTransformed(
				actionMetaData.position,
				scaleVector,
				actionMetaData.rotation,
				stickerTexture,
				{
					CombineType = Enum.ImageCombineType.Overwrite,
					SamplingMode = Enum.ResamplerMode.Default,
				}
			)

			TextureUtils.performRegionStencil(currentRegionMap, prevStickerBuffer, stickerLayer)
		end
	end,
}

--[=[
	@within ImageEditActions
	@prop RemoveStickerAction ImageEditAction

	Wipes a sticker layer and drops it out of the mesh part's layer stack.
]=]
ImageEditActions.RemoveStickerAction = {
	isValidAction = function(modelInfo, actionMetaData: RemoveStickerActionMetadata)
		if actionMetaData.stickerLayerNumber < 1 then
			return false
		end

		if actionMetaData.stickerLayerNumber > CreationConfig.maxStickerLayers then
			return false
		end

		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: RemoveStickerActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

		local stickerLayerName = CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber

		local stickerLayer: EditableImage, _didCreateLayer: boolean =
			textureInfo:getOrCreateLayer(targetMeshPart, stickerLayerName)
		TextureUtils.clear(stickerLayer)
		textureInfo:removeLayer(targetMeshPart, stickerLayerName)
	end,
}

--[=[
	@within ImageEditActions
	@prop ProjectedStickerAction ImageEditAction

	Projects a sticker onto the mesh from a direction, so it wraps around geometry.
]=]
ImageEditActions.ProjectedStickerAction = {
	isValidAction = function(modelInfo, actionMetaData: ProjectedStickerActionMetadata)
		if
			not actionMetaData.rotation
			or not actionMetaData.scale
			or not actionMetaData.direction
			or not actionMetaData.position
		then
			return false
		end

		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		if actionMetaData.stickerLayerNumber < 1 then
			return false
		end

		if actionMetaData.stickerLayerNumber > CreationConfig.maxStickerLayers then
			return false
		end

		if not isValidPaintLayer(modelInfo, actionMetaData.paintLayerId) then
			return false
		end

		if not isAllowedSticker(actionMetaData.textureId) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: ProjectedStickerActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local stickerLayer: EditableImage, didCreateLayer: boolean = textureInfo:getOrCreateLayer(
			targetMeshPart,
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber
		)
		textureInfo:setStickerPaintLayer(
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber,
			actionMetaData.paintLayerId
		)

		if not didCreateLayer and actionMetaData.clearTexture then
			TextureUtils.clear(stickerLayer)
		end

		local texelsPerStud =
			modelInfo:getTexelsPerStud(targetMeshPart, actionMetaData.position, actionMetaData.scale / 2)
		local projectedSize = actionMetaData.scale * texelsPerStud * CreationConfig.projectedSticker.oversample
		local stickerTexture = textureInfo:getStickerImage(actionMetaData.textureId, projectedSize)

		local projectionRotater = CFrame.fromAxisAngle(actionMetaData.direction, actionMetaData.rotation)

		local projection: ProjectionParams = {
			Direction = actionMetaData.direction,
			Position = actionMetaData.position,
			Size = Vector3.one * actionMetaData.scale,
			Up = projectionRotater * Vector3.new(0, 1, 0),
		}

		local localBrushConfig: BrushConfig = {
			Decal = stickerTexture,
			ColorBlendType = Enum.ImageCombineType.BlendSourceOver,
			AlphaBlendType = Enum.ImageAlphaType.Default,
			BlendIntensity = 1,
			FadeAngle = CreationConfig.projectedSticker.fadeAngle,
		}

		local meshInfo = modelInfo:getMeshInfo()
		local editableMesh = meshInfo:getEditableMesh(targetMeshPart)

		stickerLayer:DrawImageProjected(editableMesh, projection, localBrushConfig)
	end,
}

--[=[
	@within ImageEditActions
	@prop TiledStickerAction ImageEditAction

	Repeats a sticker across the whole layer on a rotated lattice, stencilled to a region.
]=]
ImageEditActions.TiledStickerAction = {
	isValidAction = function(modelInfo, actionMetaData: TiledStickerActionMetadata)
		if
			not actionMetaData.rotation
			or not actionMetaData.scale
			or not actionMetaData.texturePosition
			or not actionMetaData.tilePadding
		then
			return false
		end

		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		if actionMetaData.stickerLayerNumber < 1 then
			return false
		end

		if actionMetaData.stickerLayerNumber > CreationConfig.maxStickerLayers then
			return false
		end

		if not isValidPaintLayer(modelInfo, actionMetaData.paintLayerId) then
			return false
		end

		if not isAllowedSticker(actionMetaData.textureId) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: TiledStickerActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local stickerLayer: EditableImage, didCreateLayer: boolean = textureInfo:getOrCreateLayer(
			targetMeshPart,
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber
		)
		textureInfo:setStickerPaintLayer(
			CreationConfig.layerNames.stickerPrefix .. actionMetaData.stickerLayerNumber,
			actionMetaData.paintLayerId
		)
		local isAccessory = modelInfo:getCreationType() == CreationConfig.creationTypes.accessory
		local atlasLayout = modelInfo:getAtlasLayout()
		local kitbashingEnabled = atlasLayout ~= nil

		if not didCreateLayer then
			TextureUtils.clear(stickerLayer)
		end

		local stickerTexture: EditableImage = textureInfo:getOrCreateEditableImageByTextureId(actionMetaData.textureId)

		local rotation = actionMetaData.rotation * -(math.pi / 180)

		local normVec = Vector3.new(0, 0, -1)
		local rotator = CFrame.fromAxisAngle(normVec, rotation)
		local upVec3 = rotator * Vector3.new(0, 1, 0)
		local rightVec3 = rotator * Vector3.new(1, 0, 0)

		local globalScale = 0.5

		local clampScale = math.max(
			actionMetaData.scale,
			if isAccessory
				then CreationConfig.defaultTiledStickerScale * CreationConfig.accessoryStickerScale
				else CreationConfig.defaultTiledStickerScale
		)
		local upScale = actionMetaData.tilePadding + (clampScale * stickerTexture.Size.Y * globalScale)
		local rightScale = actionMetaData.tilePadding + (clampScale * stickerTexture.Size.X * globalScale)

		local function getSideLengthFromNormal(pos: Vector2, normal: Vector2, size: Vector2)
			local corners = {}
			corners[1] = Vector2.new(0, 0)
			corners[2] = Vector2.new(0, size.Y)
			corners[3] = Vector2.new(size.X, 0)
			corners[4] = size

			local largest = -math.huge
			local smallest = math.huge
			for _, cornerPos in pairs(corners) do
				local deltaVec = cornerPos - pos
				local deltaMag = normal:Dot(deltaVec)

				if largest < deltaMag then
					largest = deltaMag
				end
				if smallest > deltaMag then
					smallest = deltaMag
				end
			end
			return smallest, largest
		end

		local upVec = Vector2.new(upVec3.X, upVec3.Y) * upScale
		local rightVec = Vector2.new(rightVec3.X, rightVec3.Y) * rightScale

		local layerSize = if atlasLayout
			then select(2, AtlasUtil.toPixels(atlasLayout.base, stickerLayer.Size))
			else stickerLayer.Size

		local leftLimit, rightLimit = getSideLengthFromNormal(actionMetaData.texturePosition, rightVec.Unit, layerSize)
		local upLimit, downLimit = getSideLengthFromNormal(actionMetaData.texturePosition, upVec.Unit, layerSize)

		leftLimit = math.floor(leftLimit / rightScale)
		rightLimit = math.ceil(rightLimit / rightScale)

		upLimit = math.floor(upLimit / upScale)
		downLimit = math.ceil(downLimit / upScale)

		local drawnSize = math.max(stickerTexture.Size.X, stickerTexture.Size.Y) * clampScale * globalScale
		local tileTexture = textureInfo:getStickerImage(actionMetaData.textureId, drawnSize)
		local scaleVector = Vector2.one * (drawnSize / math.max(tileTexture.Size.X, tileTexture.Size.Y))

		if kitbashingEnabled then
			local temporaryLayer = AssetService:CreateEditableImage({ Size = layerSize })
			if not temporaryLayer then
				error(CreationStrings.failedToCreateImage)
			end

			local prevBuffer = stickerLayer:ReadPixelsBuffer(Vector2.zero, temporaryLayer.Size)

			for yIter = leftLimit, rightLimit do
				for xIter = upLimit, downLimit do
					temporaryLayer:DrawImageTransformed(
						actionMetaData.texturePosition + (yIter * rightVec) + (xIter * upVec),
						scaleVector,
						actionMetaData.rotation,
						tileTexture,
						{
							CombineType = Enum.ImageCombineType.BlendSourceOver,
							SamplingMode = Enum.ResamplerMode.Default,
						}
					)
				end
			end

			local currentRegion = textureInfo:getRegion(actionMetaData.regionName)

			TextureUtils.performRegionStencil(currentRegion, prevBuffer, temporaryLayer)

			stickerLayer:DrawImage(Vector2.zero, temporaryLayer, Enum.ImageCombineType.Overwrite)

			temporaryLayer:Destroy()
		else
			local prevBuffer = stickerLayer:ReadPixelsBuffer(Vector2.zero, stickerLayer.Size)

			for yIter = leftLimit, rightLimit do
				for xIter = upLimit, downLimit do
					stickerLayer:DrawImageTransformed(
						actionMetaData.texturePosition + (yIter * rightVec) + (xIter * upVec),
						scaleVector,
						actionMetaData.rotation,
						tileTexture,
						{
							CombineType = Enum.ImageCombineType.BlendSourceOver,
							SamplingMode = Enum.ResamplerMode.Default,
						}
					)
				end
			end

			local currentRegion = textureInfo:getRegion(actionMetaData.regionName)
			TextureUtils.performRegionStencil(currentRegion, prevBuffer, stickerLayer)
		end
	end,
}

--[=[
	@within ImageEditActions
	@prop ClearAction ImageEditAction

	Wipes one mesh part's fabric fill layer and resets its PBR maps.
]=]
ImageEditActions.ClearAction = {
	isValidAction = function(modelInfo, actionMetaData: ClearActionMetadata)
		if not modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo, actionMetaData: ClearActionMetadata)
		local targetMeshPart = modelInfo:getMeshPartByName(actionMetaData.targetMeshPartName)
		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

		local colorMap: EditableImage =
			textureInfo:getOrCreateLayer(targetMeshPart, CreationConfig.layerNames.fabricFill)

		colorMap:DrawRectangle(Vector2.new(0, 0), colorMap.Size, Color3.new(), 1.0, Enum.ImageCombineType.Overwrite)

		TextureUtils.clearPBR(textureInfo, targetMeshPart)

		return colorMap
	end,
}

--[=[
	@within ImageEditActions
	@prop ClearRegionAction ImageEditAction

	Wipes just one region of the fabric fill layer and resets that region's PBR maps.
]=]
ImageEditActions.ClearRegionAction = {
	isValidAction = function(modelInfo, actionMetaData: ClearRegionActionMetadata)
		if actionMetaData.regionName == nil then
			return false
		end

		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

		if not textureInfo:hasRegion(actionMetaData.regionName) then
			return false
		end

		return true
	end,
	executeAction = function(modelInfo: ModelInfo.ModelInfo, actionMetaData: ClearRegionActionMetadata)
		local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()
		local region: TextureInfo.Region = textureInfo:getRegion(actionMetaData.regionName)

		local clearMeshPartName = region.meshPartNames[1]
		local targetMeshPart = modelInfo:getMeshPartByName(clearMeshPartName)

		local colorMap: EditableImage =
			textureInfo:getOrCreateLayer(targetMeshPart, CreationConfig.layerNames.fabricFill)

		if region.regionBuffer then
			assert(region.regionColor, "Region color must be defined if regionBuffer is defined")

			local currentPixelsBuffer = colorMap:ReadPixelsBuffer(Vector2.zero, colorMap.Size)
			local regionPixelsBuffer = region.regionBuffer

			-- Roblox's template read an undefined global here (and an `originalEditableImage`
			-- in the else branch), so this action errored on any call. Nothing constructs a
			-- ClearRegion action, which is why that went unnoticed. Reconstructed to match
			-- ClearAction: an untouched fabric fill layer is fully transparent, so its
			-- original state is a zeroed buffer.
			local originalBuffer = buffer.create(buffer.len(currentPixelsBuffer))

			local regionR255 = region.regionColor.r
			local regionG255 = region.regionColor.g
			local regionB255 = region.regionColor.b

			for i = 0, buffer.len(currentPixelsBuffer) - 1, 4 do
				if
					buffer.readu8(regionPixelsBuffer, i) == regionR255
					and buffer.readu8(regionPixelsBuffer, i + 1) == regionG255
					and buffer.readu8(regionPixelsBuffer, i + 2) == regionB255
				then
					buffer.writeu8(currentPixelsBuffer, i, buffer.readu8(originalBuffer, i))
					buffer.writeu8(currentPixelsBuffer, i + 1, buffer.readu8(originalBuffer, i + 1))
					buffer.writeu8(currentPixelsBuffer, i + 2, buffer.readu8(originalBuffer, i + 2))
					buffer.writeu8(currentPixelsBuffer, i + 3, buffer.readu8(originalBuffer, i + 3))
				end
			end

			colorMap:WritePixelsBuffer(Vector2.zero, colorMap.Size, currentPixelsBuffer)

			TextureUtils.applyPBRToRegion(modelInfo, textureInfo, region, false)
		else
			TextureUtils.clear(colorMap)
			TextureUtils.clearPBR(textureInfo, targetMeshPart)
		end

		return colorMap
	end,
}

--[=[
	@within ImageEditActions
	@prop ProjectionBrushAction ImageEditAction

	Paints a camera-projected stroke across every mesh part the projector overlaps, so a stroke
	crosses seams between parts.
]=]
ImageEditActions.ProjectionBrushAction = {
	isValidAction = function(modelInfo, actionMetaData: ProjectionBrushActionMetadata)
		if not actionMetaData.brushColor then
			return false
		end

		if not getPaintLayerImage(modelInfo, actionMetaData.referenceMeshPartName, actionMetaData.paintLayerId) then
			return false
		end

		if #actionMetaData.drawPositions <= 0 then
			return false
		end

		return isKnownTipId(actionMetaData.tipId)
	end,
	executeAction = function(modelInfo, actionMetaData: ProjectionBrushActionMetadata)
		local referenceMeshPart = modelInfo:getMeshPartByName(actionMetaData.referenceMeshPartName)
		local textureInfo = modelInfo:getTextureInfo()
		local targetLayer: EditableImage = getPaintLayerImage(
			modelInfo,
			actionMetaData.referenceMeshPartName,
			actionMetaData.paintLayerId
		) :: EditableImage
		local isErasing = actionMetaData.alphaBlendType ~= Enum.ImageAlphaType.Default

		local intermediateEditableImage = nil
		local imageToDrawOn = targetLayer
		if not isErasing then
			intermediateEditableImage = textureInfo:getMemorySafeEditableImage(nil, targetLayer.Size)
			intermediateEditableImage:WritePixelsBuffer(
				Vector2.zero,
				targetLayer.Size,
				actionMetaData.intermediateEditableImageBuffer
			)

			imageToDrawOn = intermediateEditableImage
		end

		local projectionBrushCircleTexture, projectionBrushLineTexture, circleBrushConfig, lineBrushConfig =
			TextureUtils.createAndSetupProjectionBrushTexturesAndConfigs(
				actionMetaData.brushColor,
				actionMetaData.colorBlendType,
				actionMetaData.alphaBlendType,
				actionMetaData.tipId
			)

		local pbrInfo, pbrBrushTextures = TextureUtils.generatePBRInfo(
			actionMetaData.alphaBlendType ~= Enum.ImageAlphaType.Default,
			actionMetaData.isReflectiveMode,
			textureInfo:getRoughnessMap(referenceMeshPart),
			textureInfo:getMetalnessMap(referenceMeshPart),
			textureInfo:getNormalMap(referenceMeshPart),
			actionMetaData.tipId
		)

		local meshInfo = modelInfo:getMeshInfo()
		local allEditableMesh = meshInfo:getEditableMeshMap()

		local cameraCFrame = referenceMeshPart.CFrame:ToWorldSpace(actionMetaData.cameraCFrame)
		local cameraDirection = cameraCFrame.LookVector

		local lastCastedPoint = referenceMeshPart.CFrame:PointToWorldSpace(actionMetaData.drawPositions[1])
		for _, currentPosition in pairs(actionMetaData.drawPositions) do
			local castedPoint = referenceMeshPart.CFrame:PointToWorldSpace(currentPosition)
			local scaledBrushSize = actionMetaData.brushSize

			local pbResult =
				TextureUtils.generateProjectionBrushPoints(lastCastedPoint, castedPoint, cameraCFrame, scaledBrushSize)

			for currMeshPart, currEditableMesh in pairs(allEditableMesh) do
				local collisionTest =
					GeometryUtil.testObbCollision(currMeshPart, pbResult.projectorCFrame, pbResult.projectorBrushSize)
				if collisionTest then
					TextureUtils.drawProjectionBrush(
						cameraDirection,
						currMeshPart,
						currEditableMesh,
						pbResult.castedPointOffSet,
						pbResult.castedCenterPointOffSet,
						scaledBrushSize,
						pbResult.castedDeltaVecLength,
						pbResult.castedUp,
						circleBrushConfig,
						lineBrushConfig,
						imageToDrawOn,
						pbrInfo
					)
				end
			end

			lastCastedPoint = castedPoint
		end

		-- Transparency is applied to the whole intermediate stroke before it lands on the target,
		-- so overlapping stamps within one stroke do not compound.
		if not isErasing then
			TextureUtils.applyAlpha(intermediateEditableImage, actionMetaData.brushTransparency)
			targetLayer:WritePixelsBuffer(Vector2.zero, targetLayer.Size, actionMetaData.cachedTargetImageBuffer)
			targetLayer:DrawImage(Vector2.zero, intermediateEditableImage, Enum.ImageCombineType.BlendSourceOver)
		end

		projectionBrushLineTexture:Destroy()
		projectionBrushCircleTexture:Destroy()
		for _, pbrBrushTexture in pairs(pbrBrushTextures) do
			pbrBrushTexture:Destroy()
		end
	end,
}

return ImageEditActions

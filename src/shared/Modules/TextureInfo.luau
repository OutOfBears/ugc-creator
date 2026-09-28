local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtlasUtil = require("./Utils/AtlasUtil")
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local RegionMaps = require(ReplicatedStorage.Shared.Data.RegionMaps)

export type SingleLayer = {
	name: string,
	editableImage: EditableImage,
}

export type KitbashAtlasInfo = {
	originalTextureSize: Vector2,
	atlasSize: Vector2,
	accessoryUOffset: number,
	accessoryUScale: number,
	kitbashUOffset: number,
	kitbashUScale: number,
}

export type PaintLayer = {
	id: string,
	blendMode: string,
	visible: boolean,
}

export type LayerInfo = {
	originalTextureId: string,
	inputLayers: { SingleLayer },
	outputEditableImage: EditableImage,
	paintImages: { [string]: EditableImage },
	reservedFillEditableImage: EditableImage,
	metalnessEI: EditableImage,
	roughnessEI: EditableImage,
	normalEI: EditableImage,
	kitbashAtlasInfo: KitbashAtlasInfo?,
}

export type ModelTextureInfo = { [MeshPart]: LayerInfo }

export type UniqueLayerMap = { [MeshPart]: LayerInfo }

export type Region = {
	name: string,
	meshPartNames: { string },

	regionBuffer: buffer?,
	regionSize: Vector2?,
	regionColor: RegionMaps.ColorUInt8?,
}

export type RegionMap = { [string]: Region }

export type TextureInfo = {
	-- vars
	creationType: string,
	individualPartsNames: { [string]: boolean },
	enableKitbashing: boolean?,
	regionMap: RegionMap,
	perMeshPartRegionMap: RegionMap,
	reservedStickerEditableImageMap: { [string]: EditableImage },
	modelTextureInfo: ModelTextureInfo,
	lastCreatedEditableImage: EditableImage?,
	lastCreatedEditableImageTextureId: string?,
	memorySafeEditableImage: EditableImage?,
	paintLayers: { PaintLayer },
	stickerPaintLayers: { [string]: string },
	blendScratchImages: { [string]: EditableImage },
	-- methods
	getMemorySafeEditableImage: (self: TextureInfo, textureId: string?, size: Vector2?) -> EditableImage,
	hasRegion: (self: TextureInfo, regionName: string) -> boolean,
	getRegion: (self: TextureInfo, regionName: string) -> Region,
	getMeshPartRegion: (self: TextureInfo, meshPartName: string) -> Region,
	getUniqueLayerMap: (self: TextureInfo) -> UniqueLayerMap,
	getUniqueLayerMapForMeshPartNames: (self: TextureInfo, meshPartNames: { string }) -> UniqueLayerMap,
	getMetalnessMap: (self: TextureInfo, meshPart: MeshPart) -> EditableImage,
	getRoughnessMap: (self: TextureInfo, meshPart: MeshPart) -> EditableImage,
	getNormalMap: (self: TextureInfo, meshPart: MeshPart) -> EditableImage,
	getBaseLayer: (self: TextureInfo, meshPart: MeshPart) -> EditableImage,
	getTextureSize: (self: TextureInfo, meshPart: MeshPart) -> Vector2,
	getImageSize: (self: TextureInfo, meshPart: MeshPart) -> Vector2,
	getOrCreateLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> (EditableImage, boolean),
	removeLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> (),
	hasLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> boolean,
	updateOutputColorMap: (self: TextureInfo, meshPart: MeshPart) -> (),
	flushOutputColorMap: (self: TextureInfo, meshPart: MeshPart) -> (),
	getAtlasSlotRect: (self: TextureInfo, meshPart: MeshPart, atlasSlot: number) -> (Vector2, Vector2),
	clearAtlasSlot: (self: TextureInfo, meshPart: MeshPart, atlasSlot: number) -> (),
	getPaintLayers: (self: TextureInfo) -> { PaintLayer },
	getPaintLayer: (self: TextureInfo, layerId: string) -> PaintLayer?,
	getPaintLayerIndex: (self: TextureInfo, layerId: string) -> number?,
	getPaintLayerImage: (self: TextureInfo, meshPart: MeshPart, layerId: string) -> EditableImage?,
	addPaintLayer: (self: TextureInfo, layerId: string) -> boolean,
	removePaintLayer: (self: TextureInfo, layerId: string) -> (),
	movePaintLayer: (self: TextureInfo, layerId: string, toIndex: number) -> (),
	setPaintLayerBlendMode: (self: TextureInfo, layerId: string, blendMode: string) -> (),
	setPaintLayerVisible: (self: TextureInfo, layerId: string, visible: boolean) -> (),
	setStickerPaintLayer: (self: TextureInfo, stickerLayerName: string, layerId: string?) -> (),
	getStickerLayerNamesOnPaintLayer: (self: TextureInfo, layerId: string) -> { string },
	getOriginalTextureId: (self: TextureInfo, meshPart: MeshPart) -> string,
	getOutputTextureByName: (self: TextureInfo, meshPartName: string) -> EditableImage?,
	getOrCreateEditableImageByTextureId: (self: TextureInfo, textureId: string) -> EditableImage,
	meshPartsShareLayer: (self: TextureInfo, meshPart1: MeshPart, meshPart2: MeshPart) -> boolean,
	destroy: (self: TextureInfo) -> (),
}

--[=[
	@class TextureInfo

	Owns every EditableImage behind one creation: the per-MeshPart layer stacks that merge down
	into the color map, the metalness/roughness/normal maps, and the region masks that stencil
	edits to a named part of the model.
]=]
local function TextureInfo(model: Model, blankData: Blanks.Blank, resolution: Vector2): TextureInfo
	local maid = Maid.new()
	local object = {} :: TextureInfo

	object.creationType = blankData.creationType
	object.individualPartsNames = blankData.individualPartsNames
	local atlasLayout = Blanks.getAtlasLayout(blankData)
	object.enableKitbashing = atlasLayout ~= nil

	local atlasCellSize = if atlasLayout
		then select(2, AtlasUtil.toPixels(atlasLayout.base, resolution))
		else resolution

	local pendingFrameUpdates: { [LayerInfo]: boolean } = {}
	local frameUpdateConnection: RBXScriptConnection? = nil

	local function getBlendScratchImage(size: Vector2, fillColor: Color3, fillTransparency: number): EditableImage?
		local key = `{size.X}x{size.Y}`
		local scratch = object.blendScratchImages[key]
		if not scratch then
			scratch = AssetService:CreateEditableImage({ Size = size })
			if not scratch then
				return nil
			end
			object.blendScratchImages[key] = scratch
		end

		scratch:DrawRectangle(Vector2.zero, size, fillColor, fillTransparency, Enum.ImageCombineType.Overwrite)

		return scratch
	end

	local function getPaintLayerGroup(layerInfo: LayerInfo, paintLayer: PaintLayer): { EditableImage }
		local group = {}

		local paintImage = layerInfo.paintImages[paintLayer.id]
		if paintImage then
			table.insert(group, paintImage)
		end

		for _, layer in layerInfo.inputLayers do
			if object.stickerPaintLayers[layer.name] == paintLayer.id then
				table.insert(group, layer.editableImage)
			end
		end

		return group
	end

	-- Subtract and Multiply are not alpha-aware: Subtract also subtracts the source alpha from the
	-- canvas, and Multiply ignores partial source alpha. A group is therefore flattened into a
	-- scratch image first (onto white for Multiply), and Subtract is followed by an opaque-black
	-- Add that restores alpha on blanks whose color map is opaque.
	local function blendPaintLayerGroup(outputImage: EditableImage, group: { EditableImage }, blendMode: string)
		local modes = CreationConfig.paintBlendModes

		if blendMode == modes.normal then
			for _, image in group do
				outputImage:DrawImage(Vector2.zero, image, Enum.ImageCombineType.BlendSourceOver)
			end
			return
		end

		local isMultiply = blendMode == modes.multiply
		local source = group[1]
		if #group > 1 or isMultiply then
			local scratch = getBlendScratchImage(outputImage.Size, Color3.new(1, 1, 1), if isMultiply then 0 else 1)
			if not scratch then
				return
			end

			for _, image in group do
				scratch:DrawImage(Vector2.zero, image, Enum.ImageCombineType.BlendSourceOver)
			end
			source = scratch
		end

		outputImage:DrawImage(Vector2.zero, source, (Enum.ImageCombineType :: any)[blendMode])

		if blendMode == modes.subtract then
			outputImage:DrawRectangle(Vector2.zero, outputImage.Size, Color3.new(0, 0, 0), 0, Enum.ImageCombineType.Add)
		end
	end

	local function isStickerLayerName(layerName: string): boolean
		local prefix = CreationConfig.layerNames.stickerPrefix

		return string.sub(layerName, 1, #prefix) == prefix
	end

	local function doMergeDownLayers(layerInfo: LayerInfo)
		local outputImage = layerInfo.outputEditableImage

		for i, layer: SingleLayer in layerInfo.inputLayers do
			if i == 1 then
				outputImage:DrawImage(Vector2.zero, layer.editableImage, Enum.ImageCombineType.Overwrite)
			elseif not isStickerLayerName(layer.name) then
				outputImage:DrawImage(Vector2.zero, layer.editableImage, Enum.ImageCombineType.BlendSourceOver)
			end
		end

		for _, paintLayer in object.paintLayers do
			if not paintLayer.visible then
				continue
			end

			local group = getPaintLayerGroup(layerInfo, paintLayer)
			if #group > 0 then
				blendPaintLayerGroup(outputImage, group, paintLayer.blendMode)
			end
		end
	end

	local function runFrameUpdates()
		frameUpdateConnection = nil

		local layerInfos = table.clone(pendingFrameUpdates)
		table.clear(pendingFrameUpdates)

		for layerInfo in layerInfos do
			doMergeDownLayers(layerInfo)
		end
	end

	local function scheduleFrameUpdate(layerInfo: LayerInfo)
		pendingFrameUpdates[layerInfo] = true

		if not frameUpdateConnection then
			frameUpdateConnection = RunService.PreRender:Once(runFrameUpdates)
		end
	end

	local destroyAllTrackedImages
	local function throwMemoryError()
		destroyAllTrackedImages()
		error(CreationStrings.failedToCreateImage)
	end

	function destroyAllTrackedImages()
		if object.memorySafeEditableImage then
			object.memorySafeEditableImage:Destroy()
			object.memorySafeEditableImage = nil
		end

		for _, scratch in object.blendScratchImages do
			scratch:Destroy()
		end
		table.clear(object.blendScratchImages)

		maid:doCleaning()
	end

	local function setupPBRTexture(size: Vector2, color: Color3): EditableImage?
		local accommodateKitbash = object.creationType == CreationConfig.creationTypes.accessory
		local eiSize = if accommodateKitbash
			then Vector2.new(size.X * CreationConfig.atlasGridSize, size.Y * CreationConfig.atlasGridSize)
			else size

		local pbrEI = AssetService:CreateEditableImage({ Size = eiSize })
		if not pbrEI then
			throwMemoryError()
			return
		end
		pbrEI:DrawRectangle(Vector2.new(0, 0), eiSize, color, 0, Enum.ImageCombineType.Overwrite)

		return pbrEI
	end

	local function createScaledEditableImage(
		imageContent: Content,
		accommodateKitbash: boolean?,
		pixelateSampling: boolean?
	): EditableImage
		local originalImage = AssetService:CreateEditableImageAsync(imageContent)
		if not originalImage then
			throwMemoryError()
		end

		local targetSize = if accommodateKitbash then atlasCellSize else resolution

		if originalImage.Size.X == targetSize.X and originalImage.Size.Y == targetSize.Y then
			return originalImage
		end

		local scaledImage = AssetService:CreateEditableImage({
			Size = targetSize,
		})
		if not scaledImage then
			originalImage:Destroy()
			throwMemoryError()
		end

		local scale = originalImage.Size.X / targetSize.X
		if originalImage.Size.Y / targetSize.Y > scale then
			scale = originalImage.Size.Y / targetSize.Y
		end

		-- An atlas cell is filled edge to edge because the part's UVs span it, even when it isn't square.
		scaledImage:DrawImageTransformed(
			Vector2.new(scaledImage.Size.X / 2, scaledImage.Size.Y / 2),
			if accommodateKitbash then targetSize / originalImage.Size else Vector2.new(1 / scale, 1 / scale),
			0,
			originalImage,
			-- Region masks must stay pixelated through a rescale or the color-to-region mapping breaks.
			if pixelateSampling then { SamplingMode = Enum.ResamplerMode.Pixelated } else nil
		)
		originalImage:Destroy()

		return scaledImage
	end

	local function setupModelTextures(): ModelTextureInfo
		local newModelInfo: ModelTextureInfo = {}

		local textureIdToLayerMap = {}

		for _, descendant in model:GetDescendants() do
			if not descendant:IsA("MeshPart") then
				continue
			end

			if descendant.Name == "PrimaryPart" then
				continue
			end

			if not object.individualPartsNames[descendant.Name] then
				continue
			end

			local existingSurfaceAppearance = descendant:FindFirstChildWhichIsA("SurfaceAppearance")
			if existingSurfaceAppearance then
				existingSurfaceAppearance:Destroy()
			end

			local hasBaseTexture = descendant.TextureID ~= ""

			if hasBaseTexture and textureIdToLayerMap[descendant.TextureID] then
				newModelInfo[descendant] = textureIdToLayerMap[descendant.TextureID]
				local sharedSurfaceAppearance = AssetService:CreateSurfaceAppearanceAsync({
					ColorMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].outputEditableImage),
					MetalnessMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].metalnessEI),
					RoughnessMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].roughnessEI),
					NormalMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].normalEI),
				})
				sharedSurfaceAppearance.Parent = descendant

				continue
			end

			local accommodateKitbash = object.enableKitbashing

			-- A layer-color head can ship with no base TextureID (its skin is the composited layer
			-- stack), so a paintable part without a texture starts from a blank editable image.
			local baseTexture
			if hasBaseTexture then
				baseTexture = createScaledEditableImage(Content.fromUri(descendant.TextureID), accommodateKitbash)
			else
				local blankSize = if accommodateKitbash then atlasCellSize else resolution
				baseTexture = AssetService:CreateEditableImage({ Size = blankSize })
			end
			if not baseTexture then
				throwMemoryError()
			end
			maid:giveTask(baseTexture)
			local baseTextureLayer: SingleLayer = {
				name = "BaseTexture",
				editableImage = baseTexture,
			}
			local originalTextureSize = baseTexture.Size

			-- The creation's own texture sits in the atlas layout's base cell at the top-left; the
			-- layout's slots are reserved for the textures of attached pieces.
			local fullTextureSize = originalTextureSize
			if accommodateKitbash then
				fullTextureSize = resolution
				local kitbashAtlas = AssetService:CreateEditableImage({
					Size = fullTextureSize,
				})
				if not kitbashAtlas then
					throwMemoryError()
				end
				maid:giveTask(kitbashAtlas)

				-- Fill canvas so there are no transparent pixels in SurfaceAppearance maps
				kitbashAtlas:DrawRectangle(
					Vector2.new(0, 0),
					fullTextureSize,
					Color3.fromRGB(255, 255, 255),
					0,
					Enum.ImageCombineType.Overwrite
				)
				kitbashAtlas:DrawImage(Vector2.new(0, 0), baseTexture, Enum.ImageCombineType.BlendSourceOver)

				baseTextureLayer.editableImage = kitbashAtlas

				baseTexture:Destroy()
			else
				local newBaseTexture = AssetService:CreateEditableImage({
					Size = fullTextureSize,
				})
				-- Roblox's template omits this guard here, though it has it at every other
				-- CreateEditableImage. Without it an exhausted budget nil-indexes below instead
				-- of raising the message [CreationController] matches to step the resolution
				-- down, so the retry ladder never runs on the non-kitbash (body) path.
				if not newBaseTexture then
					throwMemoryError()
				end
				maid:giveTask(newBaseTexture)

				-- Fill canvas so there are no transparent pixels in SurfaceAppearance maps
				newBaseTexture:DrawRectangle(
					Vector2.new(0, 0),
					fullTextureSize,
					Color3.fromRGB(255, 255, 255),
					0,
					Enum.ImageCombineType.Overwrite
				)
				newBaseTexture:DrawImage(Vector2.new(0, 0), baseTexture, Enum.ImageCombineType.BlendSourceOver)
				baseTextureLayer.editableImage = newBaseTexture
				baseTexture:Destroy()
			end

			local outputTexture = AssetService:CreateEditableImage({
				Size = fullTextureSize,
			})
			if not outputTexture then
				throwMemoryError()
			end
			maid:giveTask(outputTexture)

			local defaultPaintEI = AssetService:CreateEditableImage({ Size = fullTextureSize })
			if not defaultPaintEI then
				throwMemoryError()
			end
			maid:giveTask(defaultPaintEI)

			local fillLayerEI = AssetService:CreateEditableImage({ Size = fullTextureSize })
			if not fillLayerEI then
				throwMemoryError()
			end
			maid:giveTask(fillLayerEI)

			local metalnessEI = setupPBRTexture(CreationConfig.pbrMapCellSize, CreationConfig.pbrDefaultMetalColor)
			local roughnessEI = setupPBRTexture(CreationConfig.pbrMapCellSize, CreationConfig.pbrDefaultRoughColor)
			local normalEI = setupPBRTexture(CreationConfig.pbrMapCellSize, CreationConfig.pbrDefaultNormalColor)

			maid:giveTask(metalnessEI)
			maid:giveTask(roughnessEI)
			maid:giveTask(normalEI)

			local newLayerInfo: LayerInfo = {
				inputLayers = {
					baseTextureLayer,
					{
						name = CreationConfig.layerNames.fabricFill,
						editableImage = fillLayerEI,
					},
				},
				outputEditableImage = outputTexture,
				originalTextureId = descendant.TextureID,
				paintImages = { [CreationConfig.defaultPaintLayerId] = defaultPaintEI },
				reservedFillEditableImage = fillLayerEI,
				metalnessEI = metalnessEI,
				roughnessEI = roughnessEI,
				normalEI = normalEI,
				kitbashAtlasInfo = if accommodateKitbash
					then {
						originalTextureSize = fullTextureSize,
						atlasSize = fullTextureSize,
						accessoryUOffset = 0.0,
						accessoryUScale = 1.0 / CreationConfig.atlasGridSize,
						kitbashUOffset = 1.0 / CreationConfig.atlasGridSize,
						kitbashUScale = 1.0 / CreationConfig.atlasGridSize,
					}
					else nil,
			}

			textureIdToLayerMap[descendant.TextureID] = newLayerInfo

			doMergeDownLayers(newLayerInfo)

			local surfaceAppearance = AssetService:CreateSurfaceAppearanceAsync({
				ColorMap = Content.fromObject(outputTexture),
				MetalnessMap = Content.fromObject(metalnessEI),
				RoughnessMap = Content.fromObject(roughnessEI),
				NormalMap = Content.fromObject(normalEI),
			})
			surfaceAppearance.Parent = descendant

			newModelInfo[descendant] = newLayerInfo
		end

		return newModelInfo
	end

	local function getAllRegionBuffers(
		sourceRegionMap: RegionMaps.RegionMap
	): ({ [string]: buffer }, { [string]: Vector2 })
		local allRegionBuffers = {}
		local allRegionSizes = {}

		for _, region: RegionMaps.Region in pairs(sourceRegionMap) do
			if region.regionTextureId then
				if allRegionBuffers[region.regionTextureId] then
					continue
				end

				if allRegionBuffers[region.regionTextureId] == nil then
					local editableImage: EditableImage = createScaledEditableImage(
						Content.fromUri(region.regionTextureId),
						object.enableKitbashing,
						true
					)
					if not editableImage then
						throwMemoryError()
					end

					allRegionBuffers[region.regionTextureId] =
						editableImage:ReadPixelsBuffer(Vector2.zero, editableImage.Size)
					allRegionSizes[region.regionTextureId] = editableImage.Size
					editableImage:Destroy()
				end
			end
		end

		return allRegionBuffers, allRegionSizes
	end

	local function setupRegionMap(): RegionMap
		if not blankData.regionMapSubParts then
			return {}
		end

		local newRegionMap: RegionMap = {}

		local allRegionBuffers, allRegionSizes = getAllRegionBuffers(blankData.regionMapSubParts)

		for regionName, sourceRegion: RegionMaps.Region in pairs(blankData.regionMapSubParts) do
			local newRegion: Region = {
				name = regionName,
				meshPartNames = sourceRegion.meshPartNames,
				regionBuffer = allRegionBuffers[sourceRegion.regionTextureId],
				regionSize = allRegionSizes[sourceRegion.regionTextureId],
				regionColor = sourceRegion.regionColor,
			}

			newRegionMap[regionName] = newRegion
		end

		return newRegionMap
	end

	local function setupMeshPartToRegionMap(regionMap: RegionMaps.RegionMap): RegionMap
		local allSubRegionBuffers = {}
		local allSubRegionSizes = {}

		local meshPartToRegionMap: RegionMap = {}
		for meshPartName, regionData in pairs(regionMap) do
			if regionData.regionTextureId ~= nil then
				if allSubRegionBuffers[regionData.regionTextureId] == nil then
					local editableImage: EditableImage = createScaledEditableImage(
						Content.fromUri(regionData.regionTextureId),
						object.enableKitbashing,
						true
					)
					if not editableImage then
						throwMemoryError()
					end
					allSubRegionBuffers[regionData.regionTextureId] =
						editableImage:ReadPixelsBuffer(Vector2.zero, editableImage.Size)
					allSubRegionSizes[regionData.regionTextureId] = editableImage.Size
					editableImage:Destroy()
				end

				local newRegion: Region = {
					name = meshPartName,
					meshPartNames = meshPartName :: any,
					regionBuffer = allSubRegionBuffers[regionData.regionTextureId],
					regionSize = allSubRegionSizes[regionData.regionTextureId],
					regionColor = regionData.regionColor,
				}

				meshPartToRegionMap[meshPartName] = newRegion
			end
		end

		return meshPartToRegionMap
	end

	local function setupMemorySafeEditableImage(): EditableImage
		local safeEI = AssetService:CreateEditableImage({ Size = resolution })
		if not safeEI then
			throwMemoryError()
		end

		return safeEI
	end

	--[=[
		@within TextureInfo
		@param textureId string? -- when given, load this texture instead of an empty image
		@param size Vector2? -- size of the blank image created when no textureId is given
		@return EditableImage -- the scratch image, replacing whatever was held before

		Only one scratch image is kept alive at a time; the previous one is destroyed.
	]=]
	function object:getMemorySafeEditableImage(textureId: string?, size: Vector2?): EditableImage
		if self.memorySafeEditableImage then
			self.memorySafeEditableImage:Destroy()
			self.memorySafeEditableImage = nil
		end

		local editableImage
		if textureId then
			editableImage = createScaledEditableImage(Content.fromUri(textureId))
		else
			editableImage = AssetService:CreateEditableImage({
				Size = size,
			})
		end

		if not editableImage then
			throwMemoryError()
		end
		self.memorySafeEditableImage = editableImage

		return editableImage
	end

	--[=[
		@within TextureInfo
		@param regionName string -- name of the region
		@return boolean -- true if the creation defines that region
	]=]
	function object:hasRegion(regionName: string): boolean
		return self.regionMap[regionName] ~= nil
	end

	--[=[
		@within TextureInfo
		@param regionName string -- name of the region
		@return Region -- the region, including its mask buffer and mask color
	]=]
	function object:getRegion(regionName: string): Region
		return self.regionMap[regionName]
	end

	--[=[
		@within TextureInfo
		@param meshPartName string -- name of the mesh part
		@return Region -- the per-mesh-part region used to stencil edits on that part
	]=]
	function object:getMeshPartRegion(meshPartName: string): Region
		return self.perMeshPartRegionMap[meshPartName]
	end

	--[=[
		@within TextureInfo
		@return UniqueLayerMap -- one representative MeshPart per distinct layer stack

		Mesh parts that share a texture share a layer stack, so this collapses them to one entry.
	]=]
	function object:getUniqueLayerMap(): UniqueLayerMap
		local seenLayers = {}

		local uniqueLayerMap: UniqueLayerMap = {}

		for meshPart, layerInfo in pairs(self.modelTextureInfo) do
			if seenLayers[layerInfo] then
				continue
			end
			seenLayers[layerInfo] = true
			uniqueLayerMap[meshPart] = layerInfo
		end

		return uniqueLayerMap
	end

	--[=[
		@within TextureInfo
		@param meshPartNames { string } -- names to restrict the result to
		@return UniqueLayerMap -- one representative MeshPart per distinct layer stack among those names
	]=]
	function object:getUniqueLayerMapForMeshPartNames(meshPartNames: { string }): UniqueLayerMap
		local seenLayers = {}

		local uniqueLayerMap: UniqueLayerMap = {}

		for meshPart, layerInfo in pairs(self.modelTextureInfo) do
			if seenLayers[layerInfo] then
				continue
			end

			for _, meshPartName in pairs(meshPartNames) do
				if meshPart.Name == meshPartName then
					seenLayers[layerInfo] = true
					uniqueLayerMap[meshPart] = layerInfo
					break
				end
			end
		end

		return uniqueLayerMap
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return EditableImage -- that part's metalness map
	]=]
	function object:getMetalnessMap(meshPart: MeshPart): EditableImage
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		return layerInfo.metalnessEI
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return EditableImage -- that part's roughness map
	]=]
	function object:getRoughnessMap(meshPart: MeshPart): EditableImage
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		return layerInfo.roughnessEI
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return EditableImage -- that part's normal map
	]=]
	function object:getNormalMap(meshPart: MeshPart): EditableImage
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		return layerInfo.normalEI
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return EditableImage -- the bottom-most input layer, i.e. the unedited texture
	]=]
	function object:getBaseLayer(meshPart: MeshPart): EditableImage
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		return layerInfo.inputLayers[1].editableImage
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return Vector2 -- the drawable size for that part

		For a creation with an atlas this is its own base cell, not the whole image, so brushes stay
		inside the creation's own slot.
	]=]
	function object:getTextureSize(meshPart: MeshPart): Vector2
		local layerInfo = self.modelTextureInfo[meshPart]

		local fullTextureSize = layerInfo.outputEditableImage.Size

		if atlasLayout and layerInfo.kitbashAtlasInfo then
			return select(2, AtlasUtil.toPixels(atlasLayout.base, fullTextureSize))
		end

		return fullTextureSize
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return Vector2 -- the size of the part's whole color map, atlas included, which its UVs span
	]=]
	function object:getImageSize(meshPart: MeshPart): Vector2
		return self.modelTextureInfo[meshPart].outputEditableImage.Size
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@param atlasSlot number -- index into the blank's atlas layout slots
		@return Vector2 -- the slot's top-left pixel
		@return Vector2 -- the slot's size in pixels
	]=]
	function object:getAtlasSlotRect(meshPart: MeshPart, atlasSlot: number): (Vector2, Vector2)
		local layout = assert(atlasLayout, "This creation has no texture atlas")

		return AtlasUtil.toPixels(layout.slots[atlasSlot], self.modelTextureInfo[meshPart].outputEditableImage.Size)
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose layer stack to touch
		@param layerName string -- the fabric fill or a sticker layer name
		@return EditableImage -- the layer image
		@return boolean -- true if the layer was added to the stack by this call
	]=]
	function object:getOrCreateLayer(meshPart: MeshPart, layerName: string): (EditableImage, boolean)
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		for _, layer in layerInfo.inputLayers do
			if layer.name == layerName then
				return layer.editableImage, false
			end
		end

		local newLayer
		if layerName == CreationConfig.layerNames.fabricFill then
			newLayer = layerInfo.reservedFillEditableImage
		else
			newLayer = self.reservedStickerEditableImageMap[layerName]
			if newLayer.Size ~= layerInfo.outputEditableImage.Size then
				newLayer:Destroy()
				newLayer = AssetService:CreateEditableImage({ Size = layerInfo.outputEditableImage.Size })
				assert(newLayer, "Budget should be sufficient to create sticker layer")
				self.reservedStickerEditableImageMap[layerName] = newLayer
				maid:giveTask(newLayer)
			end
		end

		table.insert(layerInfo.inputLayers, {
			name = layerName,
			editableImage = newLayer,
		})

		return newLayer, true
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose layer stack to touch
		@param layerName string -- the layer to drop from the stack
	]=]
	function object:removeLayer(meshPart: MeshPart, layerName: string)
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		for i, layer in layerInfo.inputLayers do
			if layer.name == layerName then
				table.remove(layerInfo.inputLayers, i)
				break
			end
		end
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@param layerName string -- the layer to look for
		@return boolean -- true if that layer is in the part's stack
	]=]
	function object:hasLayer(meshPart: MeshPart, layerName: string): boolean
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		if not layerInfo then
			return false
		end

		for _, layer in layerInfo.inputLayers do
			if layer.name == layerName then
				return true
			end
		end

		return false
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose color map to rebuild

		Merges the part's input layers back down into the output image the SurfaceAppearance reads.
		The server merges immediately; the client merges at most once per frame.
	]=]
	function object:updateOutputColorMap(meshPart: MeshPart)
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		if not RunService:IsClient() then
			doMergeDownLayers(layerInfo)
			return
		end

		scheduleFrameUpdate(layerInfo)
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose output image is about to be read

		Brings the part's output image up to date right away. Call it before reading the output.
	]=]
	function object:flushOutputColorMap(meshPart: MeshPart)
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]
		if not pendingFrameUpdates[layerInfo] then
			return
		end

		pendingFrameUpdates[layerInfo] = nil
		doMergeDownLayers(layerInfo)
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose layer stack to touch
		@param atlasSlot number -- index into the blank's atlas layout slots

		Erases one kitbash atlas cell from every paint layer, e.g. when the piece or accessory textured
		by that cell is removed or swapped. Call [TextureInfo:updateOutputColorMap] afterwards.
	]=]
	function object:clearAtlasSlot(meshPart: MeshPart, atlasSlot: number)
		local position, size = self:getAtlasSlotRect(meshPart, atlasSlot)

		for _, paintLayer in self.paintLayers do
			local paintImage = self:getPaintLayerImage(meshPart, paintLayer.id)
			if not paintImage then
				continue
			end

			paintImage:DrawRectangle(position, size, Color3.new(0, 0, 0), 1, Enum.ImageCombineType.Overwrite)
		end
	end

	--[=[
		@within TextureInfo
		@return { PaintLayer } -- the player's paint layers, bottom to top
	]=]
	function object:getPaintLayers(): { PaintLayer }
		return self.paintLayers
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to look up
		@return PaintLayer? -- the layer, or nil if no layer has that id
	]=]
	function object:getPaintLayer(layerId: string): PaintLayer?
		local index = self:getPaintLayerIndex(layerId)

		return if index then self.paintLayers[index] else nil
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to look up
		@return number? -- its position in the stack, 1 being the bottom
	]=]
	function object:getPaintLayerIndex(layerId: string): number?
		for i, paintLayer in self.paintLayers do
			if paintLayer.id == layerId then
				return i
			end
		end

		return nil
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose layer stack to look in
		@param layerId string -- the paint layer
		@return EditableImage? -- the image that layer paints into on that part's stack
	]=]
	function object:getPaintLayerImage(meshPart: MeshPart, layerId: string): EditableImage?
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]
		if not layerInfo then
			return nil
		end

		return layerInfo.paintImages[layerId]
	end

	--[=[
		@within TextureInfo
		@param layerId string -- id for the new layer
		@return boolean -- false if the editable-image budget could not fit it, leaving nothing added

		Adds a Normal, visible paint layer on top of the stack, with one image per layer stack.
	]=]
	function object:addPaintLayer(layerId: string): boolean
		local created: { [LayerInfo]: EditableImage } = {}

		for _, layerInfo in self:getUniqueLayerMap() do
			local image = AssetService:CreateEditableImage({ Size = layerInfo.outputEditableImage.Size })
			if not image then
				for createdLayerInfo, createdImage in created do
					createdImage:Destroy()
					createdLayerInfo.paintImages[layerId] = nil
				end
				return false
			end

			created[layerInfo] = image
			layerInfo.paintImages[layerId] = image
		end

		table.insert(self.paintLayers, {
			id = layerId,
			blendMode = CreationConfig.paintBlendModes.normal,
			visible = true,
		})

		return true
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to delete

		Destroys the layer's images. Stickers it owns must be removed by the caller first.
	]=]
	function object:removePaintLayer(layerId: string)
		local index = self:getPaintLayerIndex(layerId)
		if not index then
			return
		end
		table.remove(self.paintLayers, index)

		for _, layerInfo in self:getUniqueLayerMap() do
			local image = layerInfo.paintImages[layerId]
			if image then
				image:Destroy()
				layerInfo.paintImages[layerId] = nil
			end
		end
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to move
		@param toIndex number -- its new position, clamped to the stack
	]=]
	function object:movePaintLayer(layerId: string, toIndex: number)
		local index = self:getPaintLayerIndex(layerId)
		if not index then
			return
		end

		local paintLayer = table.remove(self.paintLayers, index)
		table.insert(self.paintLayers, math.clamp(toIndex, 1, #self.paintLayers + 1), paintLayer)
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to change
		@param blendMode string -- a `CreationConfig.paintBlendModes` value
	]=]
	function object:setPaintLayerBlendMode(layerId: string, blendMode: string)
		local paintLayer = self:getPaintLayer(layerId)
		if paintLayer then
			paintLayer.blendMode = blendMode
		end
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer to change
		@param visible boolean -- false leaves the layer out of the merged color map
	]=]
	function object:setPaintLayerVisible(layerId: string, visible: boolean)
		local paintLayer = self:getPaintLayer(layerId)
		if paintLayer then
			paintLayer.visible = visible
		end
	end

	--[=[
		@within TextureInfo
		@param stickerLayerName string -- the sticker slot's layer name
		@param layerId string? -- the paint layer that owns it, or nil to clear
	]=]
	function object:setStickerPaintLayer(stickerLayerName: string, layerId: string?)
		self.stickerPaintLayers[stickerLayerName] = layerId
	end

	--[=[
		@within TextureInfo
		@param layerId string -- the paint layer
		@return { string } -- the sticker slot layer names that paint layer owns
	]=]
	function object:getStickerLayerNamesOnPaintLayer(layerId: string): { string }
		local names = {}
		for stickerLayerName, ownerId in self.stickerPaintLayers do
			if ownerId == layerId then
				table.insert(names, stickerLayerName)
			end
		end

		return names
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part to look up
		@return string -- the TextureID the part shipped with
	]=]
	function object:getOriginalTextureId(meshPart: MeshPart): string
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]

		return layerInfo.originalTextureId
	end

	--[=[
		@within TextureInfo
		@param meshPartName string -- name of the part to look up
		@return EditableImage? -- the merged output image, or nil if no part has that name
	]=]
	function object:getOutputTextureByName(meshPartName: string): EditableImage?
		for meshPart, layerInfo in pairs(self.modelTextureInfo) do
			if meshPart.Name == meshPartName then
				return layerInfo.outputEditableImage
			end
		end

		return nil
	end

	--[=[
		@within TextureInfo
		@param textureId string -- the texture to load
		@return EditableImage -- an image of that texture

		Only the most recently requested texture is kept, so repeated requests for the same id are
		free and switching ids destroys the previous image.
	]=]
	function object:getOrCreateEditableImageByTextureId(textureId: string): EditableImage
		if self.lastCreatedEditableImageTextureId == textureId then
			return self.lastCreatedEditableImage
		end

		if self.lastCreatedEditableImage then
			self.lastCreatedEditableImage:Destroy()
			self.lastCreatedEditableImage = nil
		end

		self.lastCreatedEditableImageTextureId = textureId

		local editableImage = AssetService:CreateEditableImageAsync(Content.fromUri(textureId))
		if not editableImage then
			error("Failed to create EditableImage for textureId: " .. textureId)
		end
		self.lastCreatedEditableImage = editableImage

		return editableImage
	end

	--[=[
		@within TextureInfo
		@param meshPart1 MeshPart -- the first part
		@param meshPart2 MeshPart -- the second part
		@return boolean -- true if both parts draw onto the same layer stack
	]=]
	function object:meshPartsShareLayer(meshPart1: MeshPart, meshPart2: MeshPart): boolean
		local layerInfo1: LayerInfo = self.modelTextureInfo[meshPart1]
		local layerInfo2: LayerInfo = self.modelTextureInfo[meshPart2]

		return layerInfo1 == layerInfo2
	end

	function object:destroy()
		if frameUpdateConnection then
			frameUpdateConnection:Disconnect()
			frameUpdateConnection = nil
		end
		table.clear(pendingFrameUpdates)

		for _, layerInfo in pairs(self.modelTextureInfo) do
			for _, layer in layerInfo.inputLayers do
				layer.editableImage:Destroy()
			end
			for _, paintImage in layerInfo.paintImages do
				paintImage:Destroy()
			end
			layerInfo.reservedFillEditableImage:Destroy()
			layerInfo.outputEditableImage:Destroy()

			layerInfo.metalnessEI:Destroy()
			layerInfo.roughnessEI:Destroy()
			layerInfo.normalEI:Destroy()
		end

		if self.lastCreatedEditableImage then
			self.lastCreatedEditableImage:Destroy()
		end
		for _, reservedStickerEI in pairs(self.reservedStickerEditableImageMap) do
			reservedStickerEI:Destroy()
		end

		destroyAllTrackedImages()
	end

	object.paintLayers = {
		{
			id = CreationConfig.defaultPaintLayerId,
			blendMode = CreationConfig.paintBlendModes.normal,
			visible = true,
		},
	}
	object.stickerPaintLayers = {}
	object.blendScratchImages = {}

	object.regionMap = setupRegionMap()
	object.perMeshPartRegionMap = setupMeshPartToRegionMap(blankData.regionMapIndividual or {})

	object.reservedStickerEditableImageMap = {}
	for i = 1, CreationConfig.maxStickerLayers do
		local stickerLayerName = CreationConfig.layerNames.stickerPrefix .. i
		local stickerEI = AssetService:CreateEditableImage({ Size = resolution })
		if not stickerEI then
			throwMemoryError()
		end
		maid:giveTask(stickerEI)
		object.reservedStickerEditableImageMap[stickerLayerName] = stickerEI
	end

	object.modelTextureInfo = setupModelTextures()

	object.lastCreatedEditableImage = nil
	object.lastCreatedEditableImageTextureId = nil
	object.memorySafeEditableImage = setupMemorySafeEditableImage()

	return object
end

return TextureInfo

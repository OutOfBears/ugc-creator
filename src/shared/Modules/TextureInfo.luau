local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local EdgeBleed = require("./Utils/EdgeBleed")
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

export type LayerInfo = {
	originalTextureId: string,
	inputLayers: { SingleLayer },
	outputEditableImage: EditableImage,
	reservedBrushEditableImage: EditableImage,
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
	getOrCreateLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> (EditableImage, boolean),
	removeLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> (),
	hasLayer: (self: TextureInfo, meshPart: MeshPart, layerName: string) -> boolean,
	updateOutputColorMap: (self: TextureInfo, meshPart: MeshPart) -> (),
	getOriginalTextureId: (self: TextureInfo, meshPart: MeshPart) -> string,
	getOutputTextureByName: (self: TextureInfo, meshPartName: string) -> EditableImage?,
	getOrCreateEditableImageByTextureId: (self: TextureInfo, textureId: string) -> EditableImage,
	meshPartsShareLayer: (self: TextureInfo, meshPart1: MeshPart, meshPart2: MeshPart) -> boolean,
	destroy: (self: TextureInfo) -> (),
}

local function doMergeDownLayers(layerInfo: LayerInfo)
	local outputImage = layerInfo.outputEditableImage

	for i, layer: SingleLayer in layerInfo.inputLayers do
		if i == 1 then
			outputImage:DrawImage(Vector2.new(0, 0), layer.editableImage, Enum.ImageCombineType.Overwrite)
		else
			outputImage:DrawImage(Vector2.new(0, 0), layer.editableImage, Enum.ImageCombineType.BlendSourceOver)
		end
	end
end

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
	object.enableKitbashing = blankData.enableKitbashing

	-- A layer-catalog blank shows its paint as a decal over the layer decals and composes the final
	-- texture later, so its paint layers stay transparent and no SurfaceAppearance is bound.
	local usesLayerDecals = blankData.layerCatalogName ~= nil

	-- The layer decals show this paint scaled down, so its transparent edges need their color bled
	-- out. That is a full-image pass, so it runs once edits pause rather than on every merge.
	local pendingEdgeBleeds: { [LayerInfo]: thread } = {}
	local function scheduleEdgeBleed(layerInfo: LayerInfo)
		local pending = pendingEdgeBleeds[layerInfo]
		if pending then
			task.cancel(pending)
		end

		pendingEdgeBleeds[layerInfo] = task.delay(CreationConfig.paintEdgeBleedDelay, function()
			pendingEdgeBleeds[layerInfo] = nil
			EdgeBleed.bleed(layerInfo.outputEditableImage)
		end)
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

		local targetSize = resolution
		if accommodateKitbash then
			targetSize = Vector2.new(
				math.floor(targetSize.X / CreationConfig.atlasGridSize),
				math.floor(targetSize.Y / CreationConfig.atlasGridSize)
			)
		end

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

		scaledImage:DrawImageTransformed(
			Vector2.new(scaledImage.Size.X / 2, scaledImage.Size.Y / 2),
			Vector2.new(1 / scale, 1 / scale),
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
				if not usesLayerDecals then
					local sharedSurfaceAppearance = AssetService:CreateSurfaceAppearanceAsync({
						ColorMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].outputEditableImage),
						MetalnessMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].metalnessEI),
						RoughnessMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].roughnessEI),
						NormalMap = Content.fromObject(textureIdToLayerMap[descendant.TextureID].normalEI),
					})
					sharedSurfaceAppearance.Parent = descendant
				end

				continue
			end

			local accommodateKitbash = object.enableKitbashing

			-- A layer-color head can ship with no base TextureID (its skin is the composited layer
			-- stack), so a paintable part without a texture starts from a blank editable image.
			local baseTexture
			if hasBaseTexture then
				baseTexture = createScaledEditableImage(Content.fromUri(descendant.TextureID), accommodateKitbash)
			else
				local blankSize = resolution
				if accommodateKitbash then
					blankSize = Vector2.new(
						math.floor(resolution.X / CreationConfig.atlasGridSize),
						math.floor(resolution.Y / CreationConfig.atlasGridSize)
					)
				end
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

			-- The kitbash atlas is a 2x2 grid whose top-left cell holds the creation's own texture;
			-- the remaining cells are reserved for the textures of attached kitbash pieces.
			local fullTextureSize = originalTextureSize
			if accommodateKitbash then
				fullTextureSize = Vector2.new(
					originalTextureSize.X * CreationConfig.atlasGridSize,
					originalTextureSize.Y * CreationConfig.atlasGridSize
				)
				local kitbashAtlas = AssetService:CreateEditableImage({
					Size = fullTextureSize,
				})
				if not kitbashAtlas then
					throwMemoryError()
				end
				maid:giveTask(kitbashAtlas)

				-- Fill canvas so there are no transparent pixels in SurfaceAppearance maps
				if not usesLayerDecals then
					kitbashAtlas:DrawRectangle(
						Vector2.new(0, 0),
						fullTextureSize,
						Color3.fromRGB(255, 255, 255),
						0,
						Enum.ImageCombineType.Overwrite
					)
				end
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
				if not usesLayerDecals then
					newBaseTexture:DrawRectangle(
						Vector2.new(0, 0),
						fullTextureSize,
						Color3.fromRGB(255, 255, 255),
						0,
						Enum.ImageCombineType.Overwrite
					)
				end
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

			local brushLayerEI = AssetService:CreateEditableImage({ Size = fullTextureSize })
			if not brushLayerEI then
				throwMemoryError()
			end
			maid:giveTask(brushLayerEI)

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
				reservedBrushEditableImage = brushLayerEI,
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

			if not usesLayerDecals then
				local surfaceAppearance = AssetService:CreateSurfaceAppearanceAsync({
					ColorMap = Content.fromObject(outputTexture),
					MetalnessMap = Content.fromObject(metalnessEI),
					RoughnessMap = Content.fromObject(roughnessEI),
					NormalMap = Content.fromObject(normalEI),
				})
				surfaceAppearance.Parent = descendant
			end

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

		For an accessory with a kitbash atlas this is the atlas cell, not the whole image, so
		brushes stay inside the creation's own slot.
	]=]
	function object:getTextureSize(meshPart: MeshPart): Vector2
		local layerInfo = self.modelTextureInfo[meshPart]

		local fullTextureSize = layerInfo.outputEditableImage.Size

		if layerInfo.kitbashAtlasInfo then
			return Vector2.new(
				math.floor(fullTextureSize.X / CreationConfig.atlasGridSize),
				math.floor(fullTextureSize.Y / CreationConfig.atlasGridSize)
			)
		end

		return fullTextureSize
	end

	--[=[
		@within TextureInfo
		@param meshPart MeshPart -- the part whose layer stack to touch
		@param layerName string -- brush, fabric fill or a sticker layer name
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
		if layerName == CreationConfig.layerNames.brush then
			newLayer = layerInfo.reservedBrushEditableImage
		elseif layerName == CreationConfig.layerNames.fabricFill then
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
	]=]
	function object:updateOutputColorMap(meshPart: MeshPart)
		local layerInfo: LayerInfo = self.modelTextureInfo[meshPart]
		doMergeDownLayers(layerInfo)

		if usesLayerDecals and RunService:IsClient() then
			scheduleEdgeBleed(layerInfo)
		end
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
		for _, pending in pendingEdgeBleeds do
			task.cancel(pending)
		end
		table.clear(pendingEdgeBleeds)

		for _, layerInfo in pairs(self.modelTextureInfo) do
			for _, layer in layerInfo.inputLayers do
				layer.editableImage:Destroy()
			end
			layerInfo.reservedBrushEditableImage:Destroy()
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

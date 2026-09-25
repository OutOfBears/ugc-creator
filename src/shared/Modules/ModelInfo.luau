local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryUtils = require("./Utils/AccessoryUtils")
local AttachmentUtils = require("./Utils/AttachmentUtils")
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local MeshInfo = require("./MeshInfo")
local MeshWidgetUtils = require("./Utils/MeshWidgetUtils")
local ResolutionManager = require("./ResolutionManager")
local TextureInfo = require("./TextureInfo")

export type ModelInfoOptions = {
	creationPrice: number?,
	resolutionIndex: number?,
}

export type ModelInfo = {
	-- vars
	model: Model,
	blank: Blanks.Blank,
	meshPartsByNameMap: { [string]: MeshPart },
	originalTextureIdMap: { [MeshPart]: string },
	meshInfo: MeshInfo.MeshInfo,
	textureInfo: TextureInfo.TextureInfo,
	meshParts: { MeshPart },
	initialModelCFrame: CFrame,
	creationPrice: number,
	resolutionIndex: number,
	stickers: { any }?,
	placedPieces: { any }?,
	sectionColors: { [string]: { color: Color3, alpha: number } }?,
	variantSelections: { [string]: number }?,
	-- methods
	getModel: (self: ModelInfo) -> Model,
	getBlankName: (self: ModelInfo) -> string,
	getCreationType: (self: ModelInfo) -> string,
	getKitbashingEnabled: (self: ModelInfo) -> boolean?,
	getLayerCatalogName: (self: ModelInfo) -> string?,
	getLayerCatalog: (self: ModelInfo) -> ColorLayers.Catalog?,
	getStickerPatterningEnabled: (self: ModelInfo) -> boolean?,
	getWidgetMeshEditingEnabled: (self: ModelInfo) -> boolean?,
	getRegionalStickerPatterningEnabled: (self: ModelInfo) -> boolean?,
	getPreviewScale: (self: ModelInfo) -> number?,
	getAvatarAssetType: (self: ModelInfo) -> Enum.AvatarAssetType?,
	getCreationPrice: (self: ModelInfo) -> number,
	getResolutionIndex: (self: ModelInfo) -> number,
	getResolution: (self: ModelInfo) -> Vector2,
	getRegionPartsList: (self: ModelInfo) -> { string },
	getInitialModelCFrame: (self: ModelInfo) -> CFrame,
	getHumanoidDescription: (self: ModelInfo) -> HumanoidDescription?,
	getTextureInfo: (self: ModelInfo) -> TextureInfo.TextureInfo,
	getMeshInfo: (self: ModelInfo) -> MeshInfo.MeshInfo,
	getMeshPartByName: (self: ModelInfo, meshPartName: string?) -> MeshPart?,
	getOriginalTextureId: (self: ModelInfo, meshPart: MeshPart?) -> string?,
	getMeshParts: (self: ModelInfo) -> { MeshPart },
	initializeMeshPartPositions: (self: ModelInfo) -> (),
	updateOutputColorMap: (self: ModelInfo) -> (),
	saveAppliedStickers: (self: ModelInfo, stickers: { any }) -> (),
	getAppliedStickers: (self: ModelInfo) -> { any },
	savePlacedKitbashPieces: (self: ModelInfo, placedPieces: { any }) -> (),
	getPlacedKitbashPieces: (self: ModelInfo) -> { any },
	saveSectionColor: (self: ModelInfo, sectionName: string, color: Color3, alpha: number) -> (),
	getSectionColors: (self: ModelInfo) -> { [string]: { color: Color3, alpha: number } },
	saveVariantSelection: (self: ModelInfo, groupName: string, optionIndex: number) -> (),
	getVariantSelections: (self: ModelInfo) -> { [string]: number },
	destroy: (self: ModelInfo) -> (),
}

local function buildMeshPartsByNameMap(model: Model): { [string]: MeshPart }
	local meshPartsByNameMap = {}

	for _, meshPart in model:GetDescendants() do
		if meshPart:IsA("MeshPart") then
			if meshPartsByNameMap[meshPart.Name] then
				error("Error setting up model: Multiple MeshParts with the same name " .. meshPart.Name .. " found.")
			end

			meshPartsByNameMap[meshPart.Name] = meshPart
		end
	end

	return meshPartsByNameMap
end

local function buildOriginalTextureIdMap(model: Model): { [MeshPart]: string }
	local originalTextureIdMap = {}

	for _, meshPart in model:GetDescendants() do
		if meshPart:IsA("MeshPart") then
			originalTextureIdMap[meshPart] = meshPart.TextureID
		end
	end

	return originalTextureIdMap
end

local function initializeMeshPartPositions(model: Model, blank: Blanks.Blank)
	local modelPositionMarker = workspace:WaitForChild("ModelPositionMarker") :: BasePart
	modelPositionMarker.Transparency = 1

	local primaryPart = model.PrimaryPart
	assert(primaryPart ~= nil, "Model " .. blank.sourceModel.Name .. " does not have a PrimaryPart")
	local originalPrimaryPartPosition: Vector3 = primaryPart.CFrame.Position

	for _, child in model:GetDescendants() do
		if child:IsA("MeshPart") then
			child.Anchored = true

			local offset = child.Position - originalPrimaryPartPosition
			child.Position = modelPositionMarker.CFrame.Position + offset + Vector3.new(0, 0, blank.initialZOffset)
		end
	end
end

--[=[
	@class ModelInfo

	Everything the editor knows about one player's creation: the model itself, the [MeshInfo] and
	[TextureInfo] that own its editable meshes and images, and the blank it was built from.

	The texture resolution index lives here rather than in [ResolutionManager], so two players
	editing at different resolutions on the same server do not disturb each other.
]=]
local function ModelInfo(model: Model, blank: Blanks.Blank, options: ModelInfoOptions?): ModelInfo
	local resolvedOptions = options or {}
	local object = {} :: ModelInfo

	object.model = model
	object.blank = blank

	object.creationPrice = resolvedOptions.creationPrice or 0
	object.resolutionIndex = ResolutionManager.clampIndex(resolvedOptions.resolutionIndex or 1)

	object.meshPartsByNameMap = buildMeshPartsByNameMap(model)
	object.originalTextureIdMap = buildOriginalTextureIdMap(model)

	--[=[
		@within ModelInfo
		@return Model -- the model being edited
	]=]
	function object:getModel(): Model
		return self.model
	end

	--[=[
		@within ModelInfo
		@return string -- the name of the blank this creation started from
	]=]
	function object:getBlankName(): string
		return self.blank.name
	end

	--[=[
		@within ModelInfo
		@return string -- a `CreationConfig.creationTypes` value
	]=]
	function object:getCreationType(): string
		return self.blank.creationType
	end

	--[=[
		@within ModelInfo
		@return boolean? -- true if kitbash pieces may be merged into this creation
	]=]
	function object:getKitbashingEnabled(): boolean?
		return self.blank.enableKitbashing
	end

	--[=[
		@within ModelInfo
		@return string? -- the color-layer catalog name this blank recolors through, if any
	]=]
	function object:getLayerCatalogName(): string?
		return self.blank.layerCatalogName
	end

	--[=[
		@within ModelInfo
		@return ColorLayers.Catalog? -- the resolved color-layer catalog, or nil if this blank has none
	]=]
	function object:getLayerCatalog(): ColorLayers.Catalog?
		local catalogName = self.blank.layerCatalogName
		return if catalogName then ColorLayers[catalogName] else nil
	end

	--[=[
		@within ModelInfo
		@return boolean? -- true if stickers may be applied
	]=]
	function object:getStickerPatterningEnabled(): boolean?
		return self.blank.enableStickerPatterning
	end

	--[=[
		@within ModelInfo
		@return boolean? -- true if the mesh may be reshaped with widgets
	]=]
	function object:getWidgetMeshEditingEnabled(): boolean?
		return self.blank.enableWidgetMeshEditing
	end

	--[=[
		@within ModelInfo
		@return boolean? -- true if stickers may be applied to a single region
	]=]
	function object:getRegionalStickerPatterningEnabled(): boolean?
		return self.blank.enableStickerPatterning and self.blank.enableRegionalStickerPatterning
	end

	--[=[
		@within ModelInfo
		@return number? -- the scale the preview model is shown at
	]=]
	function object:getPreviewScale(): number?
		return self.blank.previewScale
	end

	--[=[
		@within ModelInfo
		@return Enum.AvatarAssetType? -- the accessory type published, or nil for a full body
	]=]
	function object:getAvatarAssetType(): Enum.AvatarAssetType?
		if self.blank.avatarAssetType then
			return self.blank.avatarAssetType
		else
			return nil
		end
	end

	--[=[
		@within ModelInfo
		@return number -- the Robux price, or 0 when this creation cannot be published
	]=]
	function object:getCreationPrice(): number
		return self.creationPrice
	end

	--[=[
		@within ModelInfo
		@return number -- the rung of the resolution ladder this creation was built at
	]=]
	function object:getResolutionIndex(): number
		return self.resolutionIndex
	end

	--[=[
		@within ModelInfo
		@return Vector2 -- the texture size for this creation's resolution index
	]=]
	function object:getResolution(): Vector2
		return ResolutionManager.resolutionFor(self.resolutionIndex)
	end

	--[=[
		@within ModelInfo
		@return { string } -- the model name, which is the whole-body region, followed by each sub-part region
	]=]
	function object:getRegionPartsList(): { string }
		local regionMapSubParts = self.blank.regionMapSubParts
		local modelName = self.blank.name

		local partNames = {}

		table.insert(partNames, modelName)

		for partName, _ in regionMapSubParts do
			table.insert(partNames, partName)
		end

		return partNames
	end

	--[=[
		@within ModelInfo
		@return CFrame -- where the model sat once it was moved onto its position marker
	]=]
	--[=[
		@within ModelInfo
		@yields

		Re-seats every mesh part relative to `workspace.ModelPositionMarker`. Run once during
		construction, and again whenever the editor is re-opened on this model so the display
		rotation the player left behind does not carry over.
	]=]
	function object:initializeMeshPartPositions()
		initializeMeshPartPositions(model, blank)
	end

	function object:getInitialModelCFrame(): CFrame
		return self.initialModelCFrame
	end

	--[=[
		@within ModelInfo
		@return HumanoidDescription? -- the description shipped inside the model, if it has one
	]=]
	function object:getHumanoidDescription(): HumanoidDescription?
		return self.model:FindFirstChildWhichIsA("HumanoidDescription")
	end

	--[=[
		@within ModelInfo
		@return TextureInfo -- the creation's editable images
	]=]
	function object:getTextureInfo(): TextureInfo.TextureInfo
		return self.textureInfo
	end

	--[=[
		@within ModelInfo
		@return MeshInfo -- the creation's editable meshes
	]=]
	function object:getMeshInfo(): MeshInfo.MeshInfo
		return self.meshInfo
	end

	--[=[
		@within ModelInfo
		@param meshPartName string? -- the name to look up
		@return MeshPart? -- the matching part, or nil
	]=]
	function object:getMeshPartByName(meshPartName: string?): MeshPart?
		if not meshPartName then
			return nil
		end

		return self.meshPartsByNameMap[meshPartName]
	end

	--[=[
		@within ModelInfo
		@param meshPart MeshPart? -- the part to look up
		@return string? -- the TextureID the part shipped with, before any editing
	]=]
	function object:getOriginalTextureId(meshPart: MeshPart?): string?
		if not meshPart then
			return nil
		end

		return self.originalTextureIdMap[meshPart]
	end

	--[=[
		@within ModelInfo
		@return { MeshPart } -- only the parts the player is allowed to edit
	]=]
	function object:getMeshParts(): { MeshPart }
		return self.meshParts
	end

	--[=[
		@within ModelInfo

		Merges every layer stack down into its output color map, which is what the published model
		is textured with.
	]=]
	function object:updateOutputColorMap()
		for meshPart, _ in self.textureInfo:getUniqueLayerMap() do
			self.textureInfo:updateOutputColorMap(meshPart)
		end
	end

	--[=[
		@within ModelInfo
		@param stickers { any } -- the stickers currently applied
	]=]
	function object:saveAppliedStickers(stickers: { any })
		self.stickers = stickers
	end

	--[=[
		@within ModelInfo
		@return { any } -- the stickers currently applied
	]=]
	function object:getAppliedStickers(): { any }
		return self.stickers or {}
	end

	--[=[
		@within ModelInfo
		@param placedPieces { any } -- the kitbash pieces currently placed
	]=]
	function object:savePlacedKitbashPieces(placedPieces: { any })
		self.placedPieces = placedPieces
	end

	--[=[
		@within ModelInfo
		@return { any } -- the kitbash pieces currently placed
	]=]
	function object:getPlacedKitbashPieces(): { any }
		return self.placedPieces or {}
	end

	--[=[
		@within ModelInfo
		@param sectionName string -- the catalog section (or variant group) being colored
		@param color Color3 -- the tint chosen for it
		@param alpha number -- transparency, 0 opaque to 1 hidden
	]=]
	function object:saveSectionColor(sectionName: string, color: Color3, alpha: number)
		local sectionColors = self.sectionColors or {}
		sectionColors[sectionName] = { color = color, alpha = alpha }
		self.sectionColors = sectionColors
	end

	--[=[
		@within ModelInfo
		@return { [string]: { color: Color3, alpha: number } } -- the color chosen per section
	]=]
	function object:getSectionColors(): { [string]: { color: Color3, alpha: number } }
		return self.sectionColors or {}
	end

	--[=[
		@within ModelInfo
		@param groupName string -- the variant group whose option changed
		@param optionIndex number -- the chosen 1-based option
	]=]
	function object:saveVariantSelection(groupName: string, optionIndex: number)
		local variantSelections = self.variantSelections or {}
		variantSelections[groupName] = optionIndex
		self.variantSelections = variantSelections
	end

	--[=[
		@within ModelInfo
		@return { [string]: number } -- the selected option index per variant group
	]=]
	function object:getVariantSelections(): { [string]: number }
		return self.variantSelections or {}
	end

	function object:destroy()
		if self.model then
			self.model:Destroy()
		end

		if self.meshInfo then
			self.meshInfo:destroy()
		end
		if self.textureInfo then
			self.textureInfo:destroy()
		end
	end

	AccessoryUtils.addOriginalSizes(model)
	AccessoryUtils.resizeAccessoriesForDisplay(model)

	object.meshInfo = MeshInfo(model, blank)
	if blank.creationType == CreationConfig.creationTypes.body then
		MeshWidgetUtils.fixupWidgets(object.meshInfo)
	end

	-- A failed EditableImage setup has to tear the model down before it propagates, so the retry
	-- at a lower resolution starts from freed memory.
	local success, result = pcall(function()
		return TextureInfo(model, blank, object:getResolution())
	end)
	if not success then
		object:destroy()
		error(result)
	end
	object.textureInfo = result

	object.meshParts = {}
	for _, meshPart in model:GetDescendants() do
		if not meshPart:IsA("MeshPart") then
			continue
		end

		if meshPart.Name == "PrimaryPart" then
			continue
		end

		if not blank.individualPartsNames[meshPart.Name] then
			continue
		end

		table.insert(object.meshParts, meshPart)
	end

	AttachmentUtils.addOriginalPositions(model)

	AttachmentUtils.moveAccessoriesToAttachmentPoints(model)

	initializeMeshPartPositions(model, blank)

	local primaryPart = assert(model.PrimaryPart, "Model " .. blank.sourceModel.Name .. " does not have a PrimaryPart")
	object.initialModelCFrame = primaryPart.CFrame

	return object
end

return ModelInfo

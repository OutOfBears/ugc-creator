local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryCatalogs = require(ReplicatedStorage.Shared.Data.AccessoryCatalogs)
local AccessoryUtils = require("./Utils/AccessoryUtils")
local AttachmentUtils = require("./Utils/AttachmentUtils")
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local LayerColorCompositor = require("./LayerColorCompositor")
local Logger = require("./Logger")
local MeshInfo = require("./MeshInfo")
local MeshUtils = require("./Utils/MeshUtils")
local MeshWidgetUtils = require("./Utils/MeshWidgetUtils")
local ResolutionManager = require("./ResolutionManager")
local TextureInfo = require("./TextureInfo")

local HEAD_CELL = 0

local logger = Logger.new()

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
	accessorySelections: { [string]: number },
	accessoryFaceIds: { [string]: { number } },
	colorCompositors: { [string]: LayerColorCompositor.LayerColorCompositor | false },
	-- methods
	getModel: (self: ModelInfo) -> Model,
	getBlankName: (self: ModelInfo) -> string,
	getCreationType: (self: ModelInfo) -> string,
	getKitbashingEnabled: (self: ModelInfo) -> boolean?,
	getAtlasLayout: (self: ModelInfo) -> CreationConfig.AtlasLayout?,
	getLayerCatalogName: (self: ModelInfo) -> string?,
	getLayerCatalog: (self: ModelInfo) -> ColorLayers.Catalog?,
	getAccessoryCatalog: (self: ModelInfo) -> AccessoryCatalogs.AccessoryCatalog?,
	getAccessorySlot: (self: ModelInfo, slotName: string) -> AccessoryCatalogs.AccessorySlot?,
	getSelectedAccessory: (self: ModelInfo, slotName: string) -> AccessoryCatalogs.AccessoryOption?,
	getAccessorySelections: (self: ModelInfo) -> { [string]: number },
	getColorTargetPart: (self: ModelInfo) -> MeshPart?,
	resolveColorKey: (self: ModelInfo, key: string) -> (ColorLayers.Catalog?, number, string),
	setAccessory: (self: ModelInfo, slotName: string, optionIndex: number) -> (),
	bakeLayerColors: (self: ModelInfo, cell: number?) -> (),
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

	object.accessorySelections = {}
	object.accessoryFaceIds = {}
	object.colorCompositors = {}

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
		@return AtlasLayout? -- how the color map is divided between this creation's own texture and attached pieces, or nil if it isn't an atlas
	]=]
	function object:getAtlasLayout(): CreationConfig.AtlasLayout?
		return Blanks.getAtlasLayout(self.blank)
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
		@return AccessoryCatalog? -- the swappable accessories for this blank, or nil if it has none
	]=]
	function object:getAccessoryCatalog(): AccessoryCatalogs.AccessoryCatalog?
		local catalogName = self.blank.accessoryCatalogName
		return if catalogName then AccessoryCatalogs[catalogName] else nil
	end

	--[=[
		@within ModelInfo
		@param slotName string -- e.g. `"Ears"`
		@return AccessorySlot? -- the slot, or nil if this blank has no such slot
	]=]
	function object:getAccessorySlot(slotName: string): AccessoryCatalogs.AccessorySlot?
		local catalog = self:getAccessoryCatalog()
		if not catalog then
			return nil
		end

		for _, slot in catalog.slots do
			if slot.name == slotName then
				return slot
			end
		end

		return nil
	end

	--[=[
		@within ModelInfo
		@param slotName string -- the slot to look up
		@return AccessoryOption? -- the option merged into that slot, or nil if it is empty
	]=]
	function object:getSelectedAccessory(slotName: string): AccessoryCatalogs.AccessoryOption?
		local slot = self:getAccessorySlot(slotName)
		local optionIndex = self.accessorySelections[slotName]

		return if slot and optionIndex then slot.options[optionIndex] else nil
	end

	--[=[
		@within ModelInfo
		@return { [string]: number } -- the selected option index per slot name, 0 for an empty slot
	]=]
	function object:getAccessorySelections(): { [string]: number }
		return self.accessorySelections
	end

	--[=[
		@within ModelInfo
		@return MeshPart? -- the part color layers and accessories are applied to
	]=]
	function object:getColorTargetPart(): MeshPart?
		return self:getMeshPartByName("Head") or self.meshParts[1]
	end

	--[=[
		@within ModelInfo
		@param key string -- a head section or variant group name, or `"<slot>.<name>"` for an accessory's
		@return ColorLayers.Catalog? -- the catalog the key belongs to, or nil if there is none
		@return number -- the atlas cell that catalog is baked into, 0 for the head
		@return string -- the section or group name within that catalog

		Accessory keys resolve against the slot's currently selected option.
	]=]
	function object:resolveColorKey(key: string): (ColorLayers.Catalog?, number, string)
		local slotName, name = string.match(key, "^(.-)%.(.+)$")
		if not slotName or not name then
			return self:getLayerCatalog(), HEAD_CELL, key
		end

		local slot = self:getAccessorySlot(slotName)
		local option = self:getSelectedAccessory(slotName)
		if not slot or not option then
			return nil, HEAD_CELL, name
		end

		return option.colors, slot.atlasSlot, name
	end

	--[=[
		@within ModelInfo
		@param slotName string -- the slot to change
		@param optionIndex number -- 1-based option, or 0 to empty an optional slot

		Swaps the accessory merged into the head: removes the previous option's faces, clears its
		atlas cell from every paint layer, merges the new option's mesh and bakes its colors. Face ids
		are local to this side, so the client and the server each track their own.
	]=]
	function object:setAccessory(slotName: string, optionIndex: number)
		local slot = assert(self:getAccessorySlot(slotName), `Unknown accessory slot '{slotName}'`)
		local targetPart = assert(self:getColorTargetPart(), "Accessories need a target part")

		local meshInfo = self:getMeshInfo()
		local targetEditableMesh = meshInfo:getKitbashEditableMeshMap()[targetPart]

		local previousFaceIds = self.accessoryFaceIds[slotName]
		if previousFaceIds then
			for _, faceId in previousFaceIds do
				targetEditableMesh:RemoveFace(faceId)
			end
			targetEditableMesh:RemoveUnused()
			self.accessoryFaceIds[slotName] = nil
		end

		self.textureInfo:clearAtlasSlot(targetPart, slot.atlasSlot)
		self.accessorySelections[slotName] = optionIndex

		local option = slot.options[optionIndex]
		if option then
			self.accessoryFaceIds[slotName] = MeshUtils.mergeKitbashPiece({
				targetMeshPart = targetPart,
				targetEditableMesh = targetEditableMesh,
				targetScaleFactor = meshInfo:getScaleFactorMap()[targetPart],
				kitbashMeshId = option.meshId,
				kitbashTextureId = "",
				positionMarkerCFrame = targetPart.CFrame * (option.offset or CFrame.identity),
				scale = option.scale or 1,
				rotation = 0,
				slotRect = assert(self:getAtlasLayout(), "Accessories need an atlas").slots[slot.atlasSlot],
				hasDrawnToAtlas = true,
			})
		end

		self:bakeLayerColors(slot.atlasSlot)
	end

	--[=[
		@within ModelInfo
		@param cell number? -- the atlas cell to repaint (0 for the head), or nil for every cell

		Composites the color layers, tinted by the stored section colors, into the base texture, then
		merges the paint back over it. A cell whose layer PNGs can't be loaded (e.g. session-only
		`rbxtemp://` ids on the server) is left white and warned about once.
	]=]
	function object:bakeLayerColors(cell: number?)
		local targetPart = self:getColorTargetPart()
		if not targetPart then
			return
		end

		local baseImage = self.textureInfo:getBaseLayer(targetPart)

		local function getCompositor(key: string, catalog: ColorLayers.Catalog, cellSize: Vector2)
			local compositor = self.colorCompositors[key]
			if compositor == nil then
				local ok, result = pcall(LayerColorCompositor, catalog, cellSize)
				if not ok and string.find(tostring(result), CreationStrings.failedToCreateImage, 1, true) then
					error(result)
				elseif not ok then
					logger:warn(`Could not load color layers for '{key}': {result}`)
				end

				compositor = if ok then result else false
				self.colorCompositors[key] = compositor
			end

			return compositor
		end

		local function bakeCell(cellIndex: number, key: string, catalog: ColorLayers.Catalog?, keyPrefix: string)
			local origin, cellSize
			if cellIndex == HEAD_CELL then
				origin, cellSize = Vector2.zero, self.textureInfo:getTextureSize(targetPart)
			else
				origin, cellSize = self.textureInfo:getAtlasSlotRect(targetPart, cellIndex)
			end

			local compositor = if catalog then getCompositor(key, catalog, cellSize) else false
			if compositor then
				compositor:composeInto(
					baseImage,
					origin,
					self:getSectionColors(),
					self:getVariantSelections(),
					keyPrefix
				)
			else
				baseImage:DrawRectangle(origin, cellSize, Color3.new(1, 1, 1), 0, Enum.ImageCombineType.Overwrite)
			end
		end

		if cell == nil or cell == HEAD_CELL then
			bakeCell(HEAD_CELL, "Head", self:getLayerCatalog(), "")
		end

		local accessoryCatalog = self:getAccessoryCatalog()
		if accessoryCatalog then
			for _, slot in accessoryCatalog.slots do
				if cell ~= nil and cell ~= slot.atlasSlot then
					continue
				end

				local option = self:getSelectedAccessory(slot.name)
				bakeCell(
					slot.atlasSlot,
					if option then `{slot.name}.{option.name}` else slot.name,
					if option then option.colors else nil,
					`{slot.name}.`
				)
			end
		end

		self.textureInfo:updateOutputColorMap(targetPart)
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
		for _, compositor in self.colorCompositors do
			if compositor then
				compositor:destroy()
			end
		end
		table.clear(self.colorCompositors)

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

	local bakeSuccess, bakeError = pcall(function()
		local accessoryCatalog = object:getAccessoryCatalog()
		if accessoryCatalog then
			for _, slot in accessoryCatalog.slots do
				object:setAccessory(slot.name, if slot.optional then 0 else 1)
			end
		end
		if blank.layerCatalogName then
			object:bakeLayerColors(0)
		end
	end)
	if not bakeSuccess then
		object:destroy()
		error(bakeError)
	end

	AttachmentUtils.addOriginalPositions(model)

	AttachmentUtils.moveAccessoriesToAttachmentPoints(model)

	initializeMeshPartPositions(model, blank)

	local primaryPart = assert(model.PrimaryPart, "Model " .. blank.sourceModel.Name .. " does not have a PrimaryPart")
	object.initialModelCFrame = primaryPart.CFrame

	return object
end

return ModelInfo

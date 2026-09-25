local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local ImageEditActions = require(ReplicatedStorage.Shared.Modules.Actions.ImageEditActions)
local LayerColorCompositor = require(ReplicatedStorage.Shared.Modules.LayerColorCompositor)
local LayerDecalPreview = require(ReplicatedStorage.Shared.Modules.LayerDecalPreview)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()

export type LayerColorTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	catalog: ColorLayers.Catalog,
	preview: LayerDecalPreview.LayerDecalPreview,
	maid: Maid.Maid,
	-- methods
	applySectionColor: (
		self: LayerColorTool,
		sectionName: string,
		color: Color3,
		opacity: number,
		isFinalInput: boolean
	) -> (),
	selectVariant: (self: LayerColorTool, groupName: string, optionIndex: number) -> (),
	composeFinalImage: (self: LayerColorTool) -> EditableImage,
	tryOn: (self: LayerColorTool) -> (),
	destroy: (self: LayerColorTool) -> (),
}

--[=[
	@class LayerColorTool
	@client

	Recolors a layered creation section by section. Each color change drives a live decal preview on
	the edit model for instant feedback and is stored on the model through a `RecolorSection` action
	(mirrored to the server on the final input of a drag). `tryOn` bakes the stored colors into one
	image with [LayerColorCompositor] and applies it to the player's own head.
]=]
local function LayerColorTool(modelInfo: ModelInfo.ModelInfo): LayerColorTool
	local maid = Maid.new()
	local object = {} :: LayerColorTool

	local catalog = modelInfo:getLayerCatalog()
	assert(catalog, "LayerColorTool requires a blank with a layer catalog")

	object.modelInfo = modelInfo
	object.catalog = catalog
	object.maid = maid

	local targetPart = modelInfo:getMeshPartByName("Head") or modelInfo:getMeshParts()[1]
	assert(targetPart, "LayerColorTool requires a mesh part to preview on")

	local sourceMeshPart = modelInfo.blank.sourceModel:FindFirstChild(targetPart.Name, true)
	assert(
		sourceMeshPart and sourceMeshPart:IsA("MeshPart"),
		`LayerColorTool could not find '{targetPart.Name}' in the blank's source model`
	)

	local paintImage = modelInfo:getTextureInfo():getOutputTextureByName(targetPart.Name)
	object.preview = maid:add(LayerDecalPreview(targetPart, sourceMeshPart, catalog, paintImage))

	local compositor: LayerColorCompositor.LayerColorCompositor? = nil

	--[=[
		@within LayerColorTool
		@param sectionName string -- the catalog section (or variant group) being colored
		@param color Color3 -- the chosen tint
		@param opacity number -- 0 transparent to 1 opaque
		@param isFinalInput boolean -- true on the last input of a drag, which is what mirrors to the server
	]=]
	function object:applySectionColor(sectionName: string, color: Color3, opacity: number, isFinalInput: boolean)
		self.preview:setSectionColor(sectionName, color, 1 - opacity)

		local metadata: ImageEditActions.RecolorSectionActionMetadata = {
			sectionName = sectionName,
			color = color,
			opacity = opacity,
		}

		local action = Actions.createAction(Actions.ActionTypes.RecolorSection, metadata)
		Actions.executeAction(self.modelInfo, action)

		if isFinalInput then
			Network.fire("SubmitAction", action)
		end
	end

	--[=[
		@within LayerColorTool
		@param groupName string -- the variant group to switch
		@param optionIndex number -- the chosen 1-based option
	]=]
	function object:selectVariant(groupName: string, optionIndex: number)
		self.preview:selectVariant(groupName, optionIndex)

		local metadata: ImageEditActions.SelectVariantActionMetadata = {
			groupName = groupName,
			optionIndex = optionIndex,
		}

		local action = Actions.createAction(Actions.ActionTypes.SelectVariant, metadata)
		Actions.executeAction(self.modelInfo, action)
		Network.fire("SubmitAction", action)
	end

	--[=[
		@within LayerColorTool
		@return EditableImage -- the tinted layers with the brush and sticker paint on top

		Composes the final texture. The layer decals and paint decal are only an editing preview; this
		is the single image a try-on or publish should apply.
	]=]
	function object:composeFinalImage(): EditableImage
		if not compositor then
			compositor = maid:add(LayerColorCompositor(self.catalog))
		end
		assert(compositor, "compositor")

		return compositor:compose(self.modelInfo:getSectionColors(), self.modelInfo:getVariantSelections(), paintImage)
	end

	--[=[
		@within LayerColorTool

		Applies the composed final texture to the local player's head.
	]=]
	function object:tryOn()
		local character = Players.LocalPlayer.Character
		if not character then
			return
		end

		local head = character:FindFirstChild("Head")
		if not head or not head:IsA("MeshPart") then
			return
		end

		head.TextureContent = Content.fromObject(self:composeFinalImage())
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return LayerColorTool

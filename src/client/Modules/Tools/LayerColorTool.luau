local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local ImageEditActions = require(ReplicatedStorage.Shared.Modules.Actions.ImageEditActions)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()

export type LayerColorTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	lastBakeTime: number,
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
	composeFinalImage: (self: LayerColorTool) -> EditableImage?,
	tryOn: (self: LayerColorTool) -> (),
	destroy: (self: LayerColorTool) -> (),
}

--[=[
	@class LayerColorTool
	@client

	Recolors a layered creation section by section. Each color change is stored on the model through
	a `RecolorSection` action, which bakes the tinted layers straight into the creation's color map;
	while dragging, bakes are throttled to `CreationConfig.layerColorBakeInterval` and only the final
	input is mirrored to the server.
]=]
local function LayerColorTool(modelInfo: ModelInfo.ModelInfo): LayerColorTool
	local maid = Maid.new()
	local object = {} :: LayerColorTool

	assert(modelInfo:getLayerCatalog(), "LayerColorTool requires a blank with a layer catalog")

	object.modelInfo = modelInfo
	object.lastBakeTime = 0
	object.maid = maid

	--[=[
		@within LayerColorTool
		@param sectionName string -- the section (or variant group) key being colored
		@param color Color3 -- the chosen tint
		@param opacity number -- 0 transparent to 1 opaque
		@param isFinalInput boolean -- true on the last input of a drag, which is what mirrors to the server
	]=]
	function object:applySectionColor(sectionName: string, color: Color3, opacity: number, isFinalInput: boolean)
		local now = os.clock()
		if not isFinalInput and now - self.lastBakeTime < CreationConfig.layerColorBakeInterval then
			return
		end
		self.lastBakeTime = now

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
		@param groupName string -- the variant group key to switch
		@param optionIndex number -- the chosen 1-based option
	]=]
	function object:selectVariant(groupName: string, optionIndex: number)
		local metadata: ImageEditActions.SelectVariantActionMetadata = {
			groupName = groupName,
			optionIndex = optionIndex,
		}

		local action = Actions.createAction(Actions.ActionTypes.SelectVariant, metadata)
		if Actions.executeAction(self.modelInfo, action) then
			Network.fire("SubmitAction", action)
		end
	end

	--[=[
		@within LayerColorTool
		@return EditableImage? -- the baked color layers with the paint on top

		The creation's merged color map — the single image a try-on or publish applies.
	]=]
	function object:composeFinalImage(): EditableImage?
		local targetPart = self.modelInfo:getColorTargetPart()

		return if targetPart then self.modelInfo:getTextureInfo():getOutputTextureByName(targetPart.Name) else nil
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
		local image = self:composeFinalImage()
		if not head or not head:IsA("MeshPart") or not image then
			return
		end

		head.TextureContent = Content.fromObject(image)
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return LayerColorTool

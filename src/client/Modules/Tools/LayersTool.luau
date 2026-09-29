local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local BrushTool = require("./BrushTool")
local Charm = require(ReplicatedStorage.Packages.Charm)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Message = require("../UI/Message")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local PaintLayerActions = require(ReplicatedStorage.Shared.Modules.Actions.PaintLayerActions)
local RandId = require(ReplicatedStorage.Shared.Modules.RandId)
local StickerTool = require("./StickerTool")
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)

export type LayerSnapshot = {
	id: string,
	name: string,
	visible: boolean,
	blendMode: string,
}

export type LayersState = {
	layers: { LayerSnapshot },
	activeLayerId: string,
	canAdd: boolean,
	canDelete: boolean,
}

export type LayersTool = {
	-- vars
	state: Charm.Atom<LayersState>,
	modelInfo: ModelInfo.ModelInfo,
	brushTool: BrushTool.BrushTool,
	stickerTool: StickerTool.StickerTool,
	activeLayerId: string,
	layerNames: { [string]: string },
	nextLayerNumber: number,
	maid: Maid.Maid,
	-- methods
	getLayers: (self: LayersTool) -> { TextureInfo.PaintLayer },
	getActiveLayerId: (self: LayersTool) -> string,
	getLayerName: (self: LayersTool, layerId: string) -> string,
	canAddLayer: (self: LayersTool) -> boolean,
	canDeleteLayer: (self: LayersTool) -> boolean,
	selectLayer: (self: LayersTool, layerId: string) -> (),
	addLayer: (self: LayersTool) -> boolean,
	deleteLayer: (self: LayersTool, layerId: string) -> (),
	moveLayer: (self: LayersTool, layerId: string, delta: number) -> (),
	setBlendMode: (self: LayersTool, layerId: string, blendMode: string) -> (),
	setVisible: (self: LayersTool, layerId: string, visible: boolean) -> (),
	submit: (self: LayersTool, actionType: string, metadata: {}) -> boolean,
	destroy: (self: LayersTool) -> (),
}

--[=[
	@class LayersTool
	@client

	Manages the player's paint layer stack: which layer the brush and new stickers target, and
	adding, deleting, reordering, hiding and re-blending layers. The stack itself lives on
	[TextureInfo]; layer display names are client-only.

	`state` is an immutable snapshot of the stack, republished after every change, for the UI to
	subscribe to.
]=]
local function LayersTool(
	modelInfo: ModelInfo.ModelInfo,
	brushTool: BrushTool.BrushTool,
	stickerTool: StickerTool.StickerTool
): LayersTool
	local maid = Maid.new()
	local object = {} :: LayersTool

	object.modelInfo = modelInfo
	object.brushTool = brushTool
	object.stickerTool = stickerTool
	object.layerNames = {}
	object.nextLayerNumber = 1
	object.maid = maid

	local textureInfo: TextureInfo.TextureInfo = modelInfo:getTextureInfo()

	local function publish()
		local layers = {}
		for index, paintLayer in object:getLayers() do
			layers[index] = {
				id = paintLayer.id,
				name = object:getLayerName(paintLayer.id),
				visible = paintLayer.visible,
				blendMode = paintLayer.blendMode,
			}
		end

		object.state({
			layers = layers,
			activeLayerId = object.activeLayerId,
			canAdd = object:canAddLayer(),
			canDelete = object:canDeleteLayer(),
		})
	end

	--[=[
		@within LayersTool
		@return { PaintLayer } -- the layers, bottom to top
	]=]
	function object:getLayers(): { TextureInfo.PaintLayer }
		return textureInfo:getPaintLayers()
	end

	--[=[
		@within LayersTool
		@return string -- id of the layer the brush and new stickers target
	]=]
	function object:getActiveLayerId(): string
		return self.activeLayerId
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to name
		@return string -- its display name
	]=]
	function object:getLayerName(layerId: string): string
		local name = self.layerNames[layerId]
		if not name then
			name = string.format(CreationStrings.layerNameFormat, self.nextLayerNumber)
			self.nextLayerNumber += 1
			self.layerNames[layerId] = name
		end

		return name
	end

	--[=[
		@within LayersTool
		@return boolean -- true while the stack is below the layer cap
	]=]
	function object:canAddLayer(): boolean
		return #self:getLayers() < CreationConfig.maxPaintLayers
	end

	--[=[
		@within LayersTool
		@return boolean -- true when more than one layer exists
	]=]
	function object:canDeleteLayer(): boolean
		return #self:getLayers() > 1
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to paint on and place stickers on
	]=]
	function object:selectLayer(layerId: string)
		self.activeLayerId = layerId
		self.brushTool:setActivePaintLayer(layerId)
		self.stickerTool:setActivePaintLayer(layerId)
		publish()
	end

	--[=[
		@within LayersTool
		@private
		@param actionType string -- an `Actions.ActionTypes` value
		@param metadata {} -- the action's payload
		@return boolean -- true if the action applied locally and was sent to the server
	]=]
	function object:submit(actionType: string, metadata: {}): boolean
		local action = Actions.createAction(actionType, metadata)
		if not Actions.executeAction(self.modelInfo, action) then
			return false
		end

		Network.fire("SubmitAction", action)
		publish()

		return true
	end

	--[=[
		@within LayersTool
		@return boolean -- true if a layer was added and selected

		Adds an empty layer on top and selects it. Shows a message when the image budget is full.
	]=]
	function object:addLayer(): boolean
		if not self:canAddLayer() then
			return false
		end

		local layerId = RandId.generateId()
		local metadata: PaintLayerActions.AddPaintLayerActionMetadata = { layerId = layerId }
		local action = Actions.createAction(Actions.ActionTypes.AddPaintLayer, metadata)

		Actions.executeAction(self.modelInfo, action)
		if not textureInfo:getPaintLayer(layerId) then
			task.spawn(Message.create, CreationStrings.layerOutOfMemory)
			return false
		end

		Network.fire("SubmitAction", action)
		self:selectLayer(layerId)

		return true
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to delete, along with its stickers

		Selects the layer that was beneath it (or the new bottom layer) when the active one goes.
	]=]
	function object:deleteLayer(layerId: string)
		if not self:canDeleteLayer() then
			return
		end

		local index = textureInfo:getPaintLayerIndex(layerId)
		if not index then
			return
		end

		self.stickerTool:forgetStickersOnLayer(layerId)

		local metadata: PaintLayerActions.RemovePaintLayerActionMetadata = { layerId = layerId }
		if not self:submit(Actions.ActionTypes.RemovePaintLayer, metadata) then
			return
		end
		self.layerNames[layerId] = nil

		if self.activeLayerId == layerId then
			local layers = self:getLayers()
			self:selectLayer(layers[math.max(index - 1, 1)].id)
		end
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to move
		@param delta number -- +1 moves it up one place, -1 down one place
	]=]
	function object:moveLayer(layerId: string, delta: number)
		local index = textureInfo:getPaintLayerIndex(layerId)
		if not index then
			return
		end

		local metadata: PaintLayerActions.MovePaintLayerActionMetadata = {
			layerId = layerId,
			toIndex = index + delta,
		}
		self:submit(Actions.ActionTypes.MovePaintLayer, metadata)
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to change
		@param blendMode string -- a `CreationConfig.paintBlendModes` value
	]=]
	function object:setBlendMode(layerId: string, blendMode: string)
		local metadata: PaintLayerActions.SetPaintLayerBlendModeActionMetadata = {
			layerId = layerId,
			blendMode = blendMode,
		}
		self:submit(Actions.ActionTypes.SetPaintLayerBlendMode, metadata)
	end

	--[=[
		@within LayersTool
		@param layerId string -- the layer to change
		@param visible boolean -- false hides it from the model
	]=]
	function object:setVisible(layerId: string, visible: boolean)
		local metadata: PaintLayerActions.SetPaintLayerVisibleActionMetadata = {
			layerId = layerId,
			visible = visible,
		}
		self:submit(Actions.ActionTypes.SetPaintLayerVisible, metadata)
	end

	function object:destroy()
		maid:doCleaning()
	end

	for _, paintLayer in object:getLayers() do
		object:getLayerName(paintLayer.id)
	end

	local layers = object:getLayers()
	object.state = Charm.atom(nil :: any)
	object:selectLayer(layers[#layers].id)

	return object
end

return LayersTool

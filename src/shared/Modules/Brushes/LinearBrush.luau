local ImageEditActions = require("../Actions/ImageEditActions")
local TextureInfo = require("../TextureInfo")
local TextureUtils = require("../Utils/TextureUtils")

type DrawInfo = {
	textureDrawPosition: Vector2,
	cameraCFrame: CFrame,
	castedPoint: Vector3,
	isVirtualCursorMovement: boolean,
	alwaysConnect: boolean?,
}

export type LinearBrush = {
	-- vars
	penSize: number,
	penColor: Color3,
	penTransparency: number,
	meshPart: MeshPart?,
	textureInfo: TextureInfo.TextureInfo,
	targetEditableImage: EditableImage,
	isPenDown: boolean,
	commitBrushStrokeCallback: ((ImageEditActions.LinearBrushActionMetadata) -> ())?,
	drawPositions: { Vector2 },
	lastPenPosition: Vector2?,
	isReflectiveMode: boolean,
	currentState: number?,
	-- methods
	setColor: (self: LinearBrush, newColor: Color3) -> (),
	setSize: (self: LinearBrush, newSize: number) -> (),
	setTransparency: (self: LinearBrush, newTransparency: number) -> (),
	setCurrentMeshPart: (self: LinearBrush, meshPart: MeshPart) -> (),
	setColorBlendType: (self: LinearBrush, colorBlendType: Enum.ImageCombineType) -> (),
	setAlphaBlendType: (self: LinearBrush, alphaBlendType: Enum.ImageAlphaType) -> (),
	setAllMeshPart: (self: LinearBrush, allMeshPart: { [MeshPart]: EditableMesh }) -> (),
	setIsReflective: (self: LinearBrush, isReflectiveMode: boolean) -> (),
	setState: (self: LinearBrush, state: number) -> (),
	setCommitBrushStrokeCallback: (
		self: LinearBrush,
		callback: (ImageEditActions.LinearBrushActionMetadata) -> ()
	) -> (),
	getRequireLocalExecute: (self: LinearBrush) -> boolean,
	doDrawAtPosition: (self: LinearBrush, newPosition: Vector2) -> (),
	penDown: (self: LinearBrush, drawInfo: DrawInfo) -> (),
	movePen: (self: LinearBrush, drawInfo: DrawInfo) -> (),
	penUp: (self: LinearBrush) -> (),
	destroy: (self: LinearBrush) -> (),
}

--[=[
	@class LinearBrush

	Paint brush that draws straight spans between consecutive pen samples directly onto the
	target image, masked by the current mesh part's region map.
]=]
local function LinearBrush(targetEditableImage: EditableImage, textureInfo: TextureInfo.TextureInfo): LinearBrush
	local object = {} :: LinearBrush

	object.penSize = 10
	object.penColor = Color3.new()
	object.penTransparency = 0

	object.meshPart = nil
	object.textureInfo = textureInfo

	object.targetEditableImage = targetEditableImage

	object.isPenDown = false

	object.commitBrushStrokeCallback = nil

	object.drawPositions = {}
	object.lastPenPosition = nil

	object.isReflectiveMode = false
	object.currentState = nil

	--[=[
		@within LinearBrush
		@param newColor Color3 -- the color painted from now on
	]=]
	function object:setColor(newColor: Color3)
		self.penColor = newColor
	end

	--[=[
		@within LinearBrush
		@param newSize number -- the brush radius in texture pixels
	]=]
	function object:setSize(newSize: number)
		self.penSize = newSize
	end

	--[=[
		@within LinearBrush
		@param newTransparency number -- 0 is opaque, 1 is invisible
	]=]
	function object:setTransparency(newTransparency: number)
		self.penTransparency = newTransparency
	end

	--[=[
		@within LinearBrush
		@param meshPart MeshPart -- the part whose region map masks the stroke
	]=]
	function object:setCurrentMeshPart(meshPart: MeshPart)
		self.meshPart = meshPart
	end

	--[=[
		@within LinearBrush
		@param colorBlendType Enum.ImageCombineType -- ignored, this brush always blends source over
	]=]
	function object:setColorBlendType(_colorBlendType: Enum.ImageCombineType) end

	--[=[
		@within LinearBrush
		@param alphaBlendType Enum.ImageAlphaType -- ignored, this brush always paints
	]=]
	function object:setAlphaBlendType(_alphaBlendType: Enum.ImageAlphaType) end

	--[=[
		@within LinearBrush
		@param allMeshPart { [MeshPart]: EditableMesh } -- ignored, this brush paints in texture space
	]=]
	function object:setAllMeshPart(_allMeshPart: { [MeshPart]: EditableMesh }) end

	--[=[
		@within LinearBrush
		@param isReflectiveMode boolean -- recorded only, this brush does not write the PBR maps
	]=]
	function object:setIsReflective(isReflectiveMode: boolean)
		self.isReflectiveMode = isReflectiveMode
	end

	--[=[
		@within LinearBrush
		@param state number -- a `CreationConfig.paintStates` value
	]=]
	function object:setState(state: number)
		self.currentState = state
	end

	--[=[
		@within LinearBrush
		@param callback (ImageEditActions.LinearBrushActionMetadata) -> () -- receives each finished stroke so it can be turned into an action
	]=]
	function object:setCommitBrushStrokeCallback(callback: (ImageEditActions.LinearBrushActionMetadata) -> ())
		self.commitBrushStrokeCallback = callback
	end

	--[=[
		@within LinearBrush
		@return boolean -- false, the committed action only runs on the server
	]=]
	function object:getRequireLocalExecute(): boolean
		return false
	end

	--[=[
		@within LinearBrush
		@private
		@param newPosition Vector2 -- texture-space position to extend the stroke to
	]=]
	function object:doDrawAtPosition(newPosition: Vector2)
		if self.lastPenPosition and (self.lastPenPosition - newPosition).Magnitude < 1 then
			return
		end

		if self.lastPenPosition == nil then
			self.lastPenPosition = newPosition
		end

		local meshPart = assert(self.meshPart, "LinearBrush has no current MeshPart")
		local currentRegionMap = self.textureInfo:getMeshPartRegion(meshPart.Name)
		local rectPosition, rectSize = TextureUtils.getStrokeRect(
			{ self.lastPenPosition, newPosition },
			self.penSize,
			self.targetEditableImage.Size
		)
		local prevBrushBuffer = if currentRegionMap
				and rectSize.X > 0
				and rectSize.Y > 0
			then self.targetEditableImage:ReadPixelsBuffer(rectPosition, rectSize)
			else nil

		TextureUtils.drawCircleBetweenPoints(
			self.lastPenPosition,
			newPosition,
			self.penSize,
			self.penColor,
			self.penTransparency,
			self.targetEditableImage
		)

		if prevBrushBuffer then
			TextureUtils.performRegionStencil(
				currentRegionMap,
				prevBrushBuffer,
				self.targetEditableImage,
				rectPosition,
				rectSize
			)
		end

		self.drawPositions[#self.drawPositions + 1] = newPosition
		self.lastPenPosition = newPosition
	end

	--[=[
		@within LinearBrush
		@param drawInfo DrawInfo -- where the stroke starts
	]=]
	function object:penDown(drawInfo: DrawInfo)
		self.isPenDown = true

		self.drawPositions = {}
		self.lastPenPosition = nil

		self:doDrawAtPosition(drawInfo.textureDrawPosition)
	end

	--[=[
		@within LinearBrush
		@param drawInfo DrawInfo -- where the pen moved to
	]=]
	function object:movePen(drawInfo: DrawInfo)
		if not self.isPenDown then
			self:penDown(drawInfo)
			return
		end

		local newPosition = drawInfo.textureDrawPosition
		local alwaysConnect = drawInfo.isVirtualCursorMovement or drawInfo.alwaysConnect == true
		if not alwaysConnect and self.lastPenPosition and (self.lastPenPosition - newPosition).Magnitude > 50 then
			-- Connecting the two positions would draw a long line across the texture, so finish
			-- the old stroke and start a new one instead.
			self:penUp()
			self:penDown(drawInfo)
			return
		end

		self:doDrawAtPosition(newPosition)
	end

	--[=[
		@within LinearBrush
	]=]
	function object:penUp()
		if not self.isPenDown then
			return
		end
		self.isPenDown = false

		if self.drawPositions == nil or #self.drawPositions == 0 then
			return
		end

		local meshPart = assert(self.meshPart, "LinearBrush has no current MeshPart")
		local linearActionMetadata: ImageEditActions.LinearBrushActionMetadata = {
			targetMeshPartName = meshPart.Name,
			brushSize = self.penSize,
			brushColor = self.penColor,
			brushTransparency = self.penTransparency,
			drawPositions = self.drawPositions,
		}

		self.drawPositions = {}

		local commitBrushStrokeCallback = assert(self.commitBrushStrokeCallback, "LinearBrush has no commit callback")
		commitBrushStrokeCallback(linearActionMetadata)
	end

	function object:destroy() end

	return object
end

return LinearBrush

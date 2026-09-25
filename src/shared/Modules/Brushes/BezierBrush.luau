local AssetService = game:GetService("AssetService")

local Maid = require("../Maid")
local TextureInfo = require("../TextureInfo")
local TextureUtils = require("../Utils/TextureUtils")

local MAX_DISCARD_TIME = 1

type DrawInfo = {
	textureDrawPosition: Vector2,
	cameraCFrame: CFrame,
	castedPoint: Vector3,
	isVirtualCursorMovement: boolean,
}

export type BrushStrokeData = {
	brushSize: number,
	brushColor: Color3,
	brushTransparency: number,
	drawPositions: { Vector2 },
}

export type BezierBrush = {
	-- vars
	penSize: number,
	penColor: Color3,
	penTransparency: number,
	meshPart: MeshPart?,
	textureInfo: TextureInfo.TextureInfo,
	targetEditableImage: EditableImage,
	workingEditableTexture: EditableImage,
	oldEditableTexture: EditableImage,
	lastPenPosition: Vector2?,
	isPenDown: boolean,
	penTimes: { number },
	penPositions: { Vector2 },
	drawnCircles: { Vector2 },
	smoothing: number,
	discardTime: number,
	commitBrushStrokeCallback: ((BrushStrokeData) -> ())?,
	maid: Maid.Maid,
	-- methods
	setColor: (self: BezierBrush, newColor: Color3) -> (),
	setSize: (self: BezierBrush, newSize: number) -> (),
	setTransparency: (self: BezierBrush, newTransparency: number) -> (),
	setSmoothness: (self: BezierBrush, newSmoothness: number) -> (),
	setCurrentMeshPart: (self: BezierBrush, meshPart: MeshPart) -> (),
	setColorBlendType: (self: BezierBrush, colorBlendType: Enum.ImageCombineType) -> (),
	setAlphaBlendType: (self: BezierBrush, alphaBlendType: Enum.ImageAlphaType) -> (),
	setAllMeshPart: (self: BezierBrush, allMeshPart: { [MeshPart]: EditableMesh }) -> (),
	setCommitBrushStrokeCallback: (self: BezierBrush, callback: (BrushStrokeData) -> ()) -> (),
	getRequireLocalExecute: (self: BezierBrush) -> boolean,
	penDown: (self: BezierBrush, drawInfo: DrawInfo) -> (),
	movePen: (self: BezierBrush, drawInfo: DrawInfo) -> (),
	penUp: (self: BezierBrush) -> (),
	drawCircle: (self: BezierBrush, position: Vector2) -> (),
	drawBetween: (self: BezierBrush, oldPosition: Vector2, newPosition: Vector2) -> (),
	redrawCurve: (self: BezierBrush) -> (),
	doMergeDown: (self: BezierBrush) -> (),
	doDraw: (self: BezierBrush, drawInfo: DrawInfo, time: number) -> (),
	finishBrushPreview: (self: BezierBrush) -> (),
	destroy: (self: BezierBrush) -> (),
}

local function factorial(value: number): number
	if value == 0 then
		return 1
	end

	return value * factorial(value - 1)
end

local function berensteinPolynomial(n: number, i: number, t: number): number
	return (factorial(n) / (factorial(i) * factorial(n - i))) * t ^ i * (1 - t) ^ (n - i)
end

local function calculatePositionAt(points: { Vector2 }, t: number): Vector2
	local n = #points

	local position = Vector2.new(0, 0)
	for i = 1, n do
		position += berensteinPolynomial(n - 1, i - 1, t) * points[i]
	end

	return position
end

--[=[
	@class BezierBrush

	Freeform paint brush that constantly redraws the last N points of the painted curve as the
	pen moves, so the stroke stays smooth while still sticking to the tip of the brush.
]=]
local function BezierBrush(targetEditableImage: EditableImage, textureInfo: TextureInfo.TextureInfo): BezierBrush
	local maid = Maid.new()
	local object = {} :: BezierBrush

	object.penSize = 10
	object.penColor = Color3.new()
	object.penTransparency = 0

	object.meshPart = nil
	object.textureInfo = textureInfo

	object.targetEditableImage = targetEditableImage

	object.workingEditableTexture = maid:add(AssetService:CreateEditableImage({
		Size = targetEditableImage.Size,
	}))
	object.oldEditableTexture = maid:add(AssetService:CreateEditableImage({
		Size = targetEditableImage.Size,
	}))

	object.lastPenPosition = nil
	object.isPenDown = false

	object.penTimes = {}
	object.penPositions = {}

	object.drawnCircles = {}

	object.smoothing = 0.25
	object.discardTime = MAX_DISCARD_TIME * object.smoothing

	object.commitBrushStrokeCallback = nil
	object.maid = maid

	--[=[
		@within BezierBrush
		@param newColor Color3 -- the color painted from now on
	]=]
	function object:setColor(newColor: Color3)
		self.penColor = newColor
	end

	--[=[
		@within BezierBrush
		@param newSize number -- the brush radius in texture pixels
	]=]
	function object:setSize(newSize: number)
		self.penSize = newSize
	end

	--[=[
		@within BezierBrush
		@param newTransparency number -- 0 is opaque, 1 is invisible
	]=]
	function object:setTransparency(newTransparency: number)
		self.penTransparency = newTransparency
	end

	--[=[
		@within BezierBrush
		@param newSmoothness number -- fraction of a second the curve keeps redrawing before it commits
	]=]
	function object:setSmoothness(newSmoothness: number)
		self.smoothing = newSmoothness
		self.discardTime = MAX_DISCARD_TIME * self.smoothing
	end

	--[=[
		@within BezierBrush
		@param meshPart MeshPart -- the part whose region map masks the stroke
	]=]
	function object:setCurrentMeshPart(meshPart: MeshPart)
		self.meshPart = meshPart
	end

	--[=[
		@within BezierBrush
		@param colorBlendType Enum.ImageCombineType -- ignored, this brush always blends source over
	]=]
	function object:setColorBlendType(_colorBlendType: Enum.ImageCombineType) end

	--[=[
		@within BezierBrush
		@param alphaBlendType Enum.ImageAlphaType -- ignored, this brush always paints
	]=]
	function object:setAlphaBlendType(_alphaBlendType: Enum.ImageAlphaType) end

	--[=[
		@within BezierBrush
		@param allMeshPart { [MeshPart]: EditableMesh } -- ignored, this brush paints in texture space
	]=]
	function object:setAllMeshPart(_allMeshPart: { [MeshPart]: EditableMesh }) end

	--[=[
		@within BezierBrush
		@param callback (BrushStrokeData) -> () -- receives each finished stroke so it can be turned into an action
	]=]
	function object:setCommitBrushStrokeCallback(callback: (BrushStrokeData) -> ())
		self.commitBrushStrokeCallback = callback
	end

	--[=[
		@within BezierBrush
		@return boolean -- true, the committed action must also run locally
	]=]
	function object:getRequireLocalExecute(): boolean
		return true
	end

	--[=[
		@within BezierBrush
		@private
		@param position Vector2 -- texture-space centre of the dab
	]=]
	function object:drawCircle(position: Vector2)
		if position.X < 0 or position.Y < 0 then
			return
		end

		if position.X > self.workingEditableTexture.Size.X or position.Y > self.workingEditableTexture.Size.Y then
			return
		end

		table.insert(self.drawnCircles, position)

		self.workingEditableTexture:DrawCircle(
			position,
			self.penSize,
			self.penColor,
			0,
			Enum.ImageCombineType.BlendSourceOver
		)
	end

	--[=[
		@within BezierBrush
		@private
		@param oldPosition Vector2 -- start of the span
		@param newPosition Vector2 -- end of the span
	]=]
	function object:drawBetween(oldPosition: Vector2, newPosition: Vector2)
		self:drawCircle(oldPosition)

		local distBetween = (oldPosition - newPosition).Magnitude

		for i = 1, distBetween, math.max(math.floor(self.penSize / 5), 1) do
			self:drawCircle(oldPosition:Lerp(newPosition, i / distBetween))
		end

		self:drawCircle(newPosition)
	end

	--[=[
		@within BezierBrush
		@private
	]=]
	function object:redrawCurve()
		if #self.penPositions == 0 then
			return
		end

		TextureUtils.clear(self.workingEditableTexture)

		self.drawnCircles = {}

		local prevTextureBuffer =
			self.workingEditableTexture:ReadPixelsBuffer(Vector2.zero, self.workingEditableTexture.Size)

		local lastPosition = self.penPositions[1]
		for i = 1, 100 do
			local newPosition = calculatePositionAt(self.penPositions, i / 100)

			self:drawBetween(lastPosition, newPosition)

			lastPosition = newPosition
		end

		local meshPart = assert(self.meshPart, "BezierBrush has no current MeshPart")
		local currentRegionMap = self.textureInfo:getMeshPartRegion(meshPart.Name)
		TextureUtils.performRegionStencil(currentRegionMap, prevTextureBuffer, self.workingEditableTexture)
	end

	--[=[
		@within BezierBrush
		@private
	]=]
	function object:doMergeDown()
		self.targetEditableImage:DrawImage(Vector2.new(0, 0), self.oldEditableTexture, Enum.ImageCombineType.Overwrite)
		self.targetEditableImage:DrawImage(
			Vector2.new(0, 0),
			self.workingEditableTexture,
			Enum.ImageCombineType.BlendSourceOver
		)
	end

	--[=[
		@within BezierBrush
		@private
		@param drawInfo DrawInfo -- where the pen is this frame
		@param time number -- the timestamp of this sample
	]=]
	function object:doDraw(drawInfo: DrawInfo, time: number)
		local position = drawInfo.textureDrawPosition
		local alwaysConnect = drawInfo.isVirtualCursorMovement
		if self.lastPenPosition then
			if (self.lastPenPosition - position).Magnitude < 3 then
				return
			elseif not alwaysConnect and (self.lastPenPosition - position).Magnitude > 50 then
				-- Connecting the two positions would draw a long line across the texture, so finish
				-- the old stroke and start a new one instead.
				self:penUp()
				self:penDown(drawInfo)
				return
			end
		end

		self.lastPenPosition = position

		table.insert(self.penTimes, time)
		table.insert(self.penPositions, position)

		self:redrawCurve()

		self:doMergeDown()

		if time - self.penTimes[1] > self.discardTime then
			self:finishBrushPreview()

			table.insert(self.penTimes, time)
			table.insert(self.penPositions, position)
		end
	end

	--[=[
		@within BezierBrush
		@param drawInfo DrawInfo -- where the stroke starts
	]=]
	function object:penDown(drawInfo: DrawInfo)
		self.isPenDown = true

		self.oldEditableTexture:DrawImage(Vector2.new(0, 0), self.targetEditableImage, Enum.ImageCombineType.Overwrite)
		self:doDraw(drawInfo, tick())
	end

	--[=[
		@within BezierBrush
		@param drawInfo DrawInfo -- where the pen moved to
	]=]
	function object:movePen(drawInfo: DrawInfo)
		if not self.isPenDown then
			self:penDown(drawInfo)
			return
		end

		self:doDraw(drawInfo, tick())
	end

	--[=[
		@within BezierBrush
	]=]
	function object:penUp()
		if not self.isPenDown then
			return
		end
		self.isPenDown = false

		self:finishBrushPreview()

		self.lastPenPosition = nil
	end

	--[=[
		@within BezierBrush
		@private

		Rolls the target image back to the pre-stroke copy and hands the accumulated dabs to the
		commit callback, which is what actually repaints the target.
	]=]
	function object:finishBrushPreview()
		self.targetEditableImage:DrawImage(Vector2.new(0, 0), self.oldEditableTexture, Enum.ImageCombineType.Overwrite)

		local newBrushStroke: BrushStrokeData = {
			brushSize = self.penSize,
			brushColor = self.penColor,
			brushTransparency = self.penTransparency,
			drawPositions = {},
		}
		for _, drawPosition in self.drawnCircles do
			table.insert(newBrushStroke.drawPositions, drawPosition)
		end

		local commitBrushStrokeCallback = assert(self.commitBrushStrokeCallback, "BezierBrush has no commit callback")
		commitBrushStrokeCallback(newBrushStroke)

		self.drawnCircles = {}
		self.penTimes = {}
		self.penPositions = {}

		self.oldEditableTexture:DrawImage(Vector2.new(0, 0), self.targetEditableImage, Enum.ImageCombineType.Overwrite)
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return BezierBrush

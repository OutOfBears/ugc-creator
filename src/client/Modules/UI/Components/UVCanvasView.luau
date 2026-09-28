local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local TextureUtils = require(ReplicatedStorage.Shared.Modules.Utils.TextureUtils)

export type UVCanvasView = {
	-- vars
	frame: Frame,
	content: Frame,
	backdrop: ImageLabel,
	underlay: Frame,
	textureStack: Frame,
	textureImages: { ImageLabel },
	cellSize: Vector2,
	wireframeImage: ImageLabel,
	handleParent: Frame,
	cursor: Frame,
	textureSize: Vector2,
	zoom: number,
	pan: Vector2,
	maid: Maid.Maid,
	-- methods
	setImages: (self: UVCanvasView, editableImages: { EditableImage }, cellSize: Vector2?) -> (),
	setWireframe: (self: UVCanvasView, editableImage: EditableImage?) -> (),
	setWireframeVisible: (self: UVCanvasView, isVisible: boolean) -> (),
	containsPoint: (self: UVCanvasView, screenPos: Vector2) -> boolean,
	screenToLocal: (self: UVCanvasView, screenPos: Vector2) -> Vector2?,
	localToOffset: (self: UVCanvasView, localPos: Vector2) -> Vector2,
	getDisplayScale: (self: UVCanvasView) -> number,
	zoomAt: (self: UVCanvasView, screenPos: Vector2, steps: number) -> (),
	panBy: (self: UVCanvasView, delta: Vector2) -> (),
	resetView: (self: UVCanvasView) -> (),
	setCursor: (self: UVCanvasView, screenPos: Vector2?, diameter: number) -> (),
	applyView: (self: UVCanvasView) -> (),
	destroy: (self: UVCanvasView) -> (),
}

--[=[
	@class UVCanvasView
	@client

	A flat, zoomable view of a texture in UV space, with an optional UV wireframe over it and a
	brush cursor. It only draws; the handler that owns it maps pointer input to texels. Screen
	positions it takes are in `AbsolutePosition` space (see `ToolInput.getGuiPosition`).

	@return UVCanvasView
]=]
local function UVCanvasView(): UVCanvasView
	local maid = Maid.new()
	local object = {} :: UVCanvasView

	object.maid = maid
	object.textureSize = Vector2.one
	object.textureImages = {}
	object.cellSize = Vector2.one
	object.zoom = 1
	object.pan = Vector2.zero

	local config = CreationConfig.uvCanvas
	local checkerImage = TextureUtils.createCheckerImage(config.checkerColorA, config.checkerColorB)
	if checkerImage then
		maid:giveTask(function()
			checkerImage:Destroy()
		end)
	end

	object.backdrop = Create("ImageLabel", {
		Name = "Backdrop",
		ImageContent = if checkerImage then Content.fromObject(checkerImage) else Content.none,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(config.checkerCellSize * 2, config.checkerCellSize * 2),
		ResampleMode = Enum.ResamplerMode.Pixelated,
		BackgroundColor3 = config.checkerColorA,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Interactable = false,
	}) :: ImageLabel

	object.underlay = Create("Frame", {
		Name = "Underlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Interactable = false,
	}) :: Frame

	object.textureStack = Create("Frame", {
		Name = "Texture",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Interactable = false,
	}) :: Frame

	object.wireframeImage = Create("ImageLabel", {
		Name = "Wireframe",
		BackgroundTransparency = 1,
		ImageTransparency = config.wireframeOverlayTransparency,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 3,
		Interactable = false,
	}) :: ImageLabel

	object.handleParent = Create("Frame", {
		Name = "Handles",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}) :: Frame

	object.content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		ZIndex = 1,
		Children = {
			object.backdrop,
			object.underlay,
			object.textureStack,
			object.wireframeImage,
			object.handleParent,
		},
	}) :: Frame

	object.cursor = Create("Frame", {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 2,
		Interactable = false,
		Tags = { StyleConsts.tags.UVCanvasCursor },
	}) :: Frame

	object.frame = maid:add(Create("Frame", {
		Name = "UVCanvas",
		ClipsDescendants = true,
		Active = true,
		Tags = { StyleConsts.tags.UVCanvas },
		Children = { object.content, object.cursor },
	}) :: Frame)

	local function getBaseScale(): number
		local viewportSize = object.frame.AbsoluteSize
		return math.min(viewportSize.X / object.textureSize.X, viewportSize.Y / object.textureSize.Y)
	end

	--[=[
		@within UVCanvasView
		@private

		Pushes the current zoom and pan onto the content frame.
	]=]
	function object:applyView()
		local contentSize = self.textureSize * getBaseScale() * self.zoom

		self.content.Size = UDim2.fromOffset(contentSize.X, contentSize.Y)
		self.content.Position = UDim2.fromOffset(self.pan.X, self.pan.Y)
	end

	--[=[
		@within UVCanvasView
		@param editableImages { EditableImage } -- the textures to stack bottom to top, shown live as they are painted
		@param cellSize Vector2? -- the region of each image to show from its top-left, in pixels

		Passing `cellSize` also resets the view to fit it; omit it to swap images in place.
	]=]
	function object:setImages(editableImages: { EditableImage }, cellSize: Vector2?)
		if cellSize then
			self.cellSize = cellSize
		end

		for index, editableImage in editableImages do
			local label = self.textureImages[index]
			if not label then
				label = Create("ImageLabel", {
					Name = `Texture{index}`,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ResampleMode = Enum.ResamplerMode.Pixelated,
					ZIndex = index,
					Interactable = false,
					Parent = self.textureStack,
				}) :: ImageLabel
				self.textureImages[index] = label
			end

			label.ImageContent = Content.fromObject(editableImage)
			label.ImageRectOffset = Vector2.zero
			label.ImageRectSize = self.cellSize
		end

		for index = #self.textureImages, #editableImages + 1, -1 do
			self.textureImages[index]:Destroy()
			self.textureImages[index] = nil
		end

		if cellSize then
			self.textureSize = cellSize
			self:resetView()
		end
	end

	--[=[
		@within UVCanvasView
		@param editableImage EditableImage? -- the wireframe overlay, or nil to clear it
	]=]
	function object:setWireframe(editableImage: EditableImage?)
		self.wireframeImage.ImageContent = if editableImage then Content.fromObject(editableImage) else Content.none
	end

	--[=[
		@within UVCanvasView
		@param isVisible boolean -- whether the wireframe overlay shows
	]=]
	function object:setWireframeVisible(isVisible: boolean)
		self.wireframeImage.Visible = isVisible
	end

	--[=[
		@within UVCanvasView
		@param screenPos Vector2 -- position in `AbsolutePosition` space
		@return boolean -- true when the position is inside the visible canvas
	]=]
	function object:containsPoint(screenPos: Vector2): boolean
		local relative = screenPos - self.frame.AbsolutePosition
		local size = self.frame.AbsoluteSize

		return self.frame.Visible
			and relative.X >= 0
			and relative.Y >= 0
			and relative.X < size.X
			and relative.Y < size.Y
	end

	--[=[
		@within UVCanvasView
		@param screenPos Vector2 -- position in `AbsolutePosition` space
		@return Vector2? -- the position as 0-1 UV over the shown texture, or nil when off it
	]=]
	function object:screenToLocal(screenPos: Vector2): Vector2?
		if not self:containsPoint(screenPos) then
			return nil
		end

		local contentSize = self.content.AbsoluteSize
		if contentSize.X <= 0 or contentSize.Y <= 0 then
			return nil
		end

		local localPos = (screenPos - self.content.AbsolutePosition) / contentSize
		if localPos.X < 0 or localPos.Y < 0 or localPos.X >= 1 or localPos.Y >= 1 then
			return nil
		end

		return localPos
	end

	--[=[
		@within UVCanvasView
		@param localPos Vector2 -- 0-1 UV over the shown texture
		@return Vector2 -- the matching offset inside the content, for placing children of `handleParent`
	]=]
	function object:localToOffset(localPos: Vector2): Vector2
		return localPos * self.content.AbsoluteSize
	end

	--[=[
		@within UVCanvasView
		@return number -- on-screen pixels per texture pixel at the current zoom
	]=]
	function object:getDisplayScale(): number
		return self.content.AbsoluteSize.X / self.textureSize.X
	end

	--[=[
		@within UVCanvasView
		@param screenPos Vector2 -- point in `AbsolutePosition` space that stays fixed while zooming
		@param steps number -- zoom steps, positive to zoom in
	]=]
	function object:zoomAt(screenPos: Vector2, steps: number)
		local newZoom = math.clamp(self.zoom * config.zoomStepFactor ^ steps, config.minZoom, config.maxZoom)
		if newZoom == self.zoom then
			return
		end

		local anchor = screenPos - self.frame.AbsolutePosition
		self.pan = anchor - (anchor - self.pan) * (newZoom / self.zoom)
		self.zoom = newZoom

		self:applyView()
	end

	--[=[
		@within UVCanvasView
		@param delta Vector2 -- on-screen pixels to move the texture by
	]=]
	function object:panBy(delta: Vector2)
		self.pan += delta
		self:applyView()
	end

	--[=[
		@within UVCanvasView

		Fits the whole texture in the canvas, centred.
	]=]
	function object:resetView()
		self.zoom = 1

		local contentSize = self.textureSize * getBaseScale()
		self.pan = (self.frame.AbsoluteSize - contentSize) / 2

		self:applyView()
	end

	--[=[
		@within UVCanvasView
		@param screenPos Vector2? -- cursor position in `AbsolutePosition` space, or nil to hide it
		@param diameter number -- on-screen diameter of the brush
	]=]
	function object:setCursor(screenPos: Vector2?, diameter: number)
		if not screenPos or not self:containsPoint(screenPos) then
			self.cursor.Visible = false
			return
		end

		local relative = screenPos - self.frame.AbsolutePosition
		self.cursor.Position = UDim2.fromOffset(relative.X, relative.Y)
		self.cursor.Size = UDim2.fromOffset(diameter, diameter)
		self.cursor.Visible = true
	end

	function object:destroy()
		maid:doCleaning()
	end

	maid:add(object.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if object.zoom == 1 then
			object:resetView()
		else
			object:applyView()
		end
	end))

	return object
end

return UVCanvasView

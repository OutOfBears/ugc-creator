local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Brushes = require(ReplicatedStorage.Shared.Modules.Brushes)
local Charm = require(ReplicatedStorage.Packages.Charm)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)
local TextureUtils = require(ReplicatedStorage.Shared.Modules.Utils.TextureUtils)
local ToolInput = require("./ToolInput")
local UVWireframe = require(ReplicatedStorage.Shared.Modules.Utils.UVWireframe)

export type UVCanvasMode = "paint" | "sticker" | "view"

type Gesture =
	"paint"
	| "pan"
	| "pinch"
	| "moveSticker"
	| "rotateSticker"
	| "scaleSticker"
	| "moveWindow"
	| "resizeWindow"

export type Rect = {
	position: Vector2,
	size: Vector2,
}

export type ContentState = {
	position: Vector2,
	size: Vector2,
	pixelated: boolean,
}

export type CursorState = {
	visible: boolean,
	position: Vector2,
	diameter: number,
}

export type HandleState = {
	visible: boolean,
	offset: Vector2,
	scale: number,
	rotation: number,
}

export type Refs = {
	container: Frame,
	viewFrame: Frame,
	resizeGrip: GuiObject,
	rotateHandle: GuiObject,
	scaleHandle: GuiObject,
}

export type UVCanvas = {
	-- vars
	modelInfo: any,
	creationInput: any,
	brushTool: any,
	stickerTool: any,
	mode: Charm.Atom<UVCanvasMode?>,
	stacks: Charm.Atom<{ MeshPart }>,
	selectedStack: Charm.Atom<MeshPart?>,
	textureImage: Charm.Atom<EditableImage?>,
	cellSize: Charm.Atom<Vector2>,
	wireframeVisible: Charm.Atom<boolean>,
	wireframeImage: Charm.Atom<EditableImage?>,
	window: Charm.Atom<Rect>,
	content: Charm.Atom<ContentState>,
	cursor: Charm.Atom<CursorState>,
	stickerHandle: Charm.Atom<HandleState>,
	maid: Maid.Maid,
	-- methods
	open: (self: UVCanvas, mode: UVCanvasMode, anchorPanel: GuiObject?) -> (),
	close: (self: UVCanvas) -> (),
	isOpen: (self: UVCanvas) -> boolean,
	selectLayerStack: (self: UVCanvas, meshPart: MeshPart) -> (),
	setWireframeVisible: (self: UVCanvas, isVisible: boolean) -> (),
	resetView: (self: UVCanvas) -> (),
	requestClose: (self: UVCanvas) -> (),
	resolvePaintTarget: (self: UVCanvas, texel: Vector2) -> MeshPart?,
	attach: (self: UVCanvas, refs: Refs?) -> (),
	destroy: (self: UVCanvas) -> (),
}

local HIDDEN_CURSOR: CursorState = { visible = false, position = Vector2.zero, diameter = 0 }
local HIDDEN_HANDLE: HandleState = { visible = false, offset = Vector2.zero, scale = 1, rotation = 0 }

--[=[
	@class UVCanvas
	@client

	The 2D canvas's behaviour: a movable, resizable window showing a layer stack's texture flat in
	UV space. Every tool can show it; in `paint` and `sticker` modes the player also paints, erases
	and places stickers on it directly, while `view` mode only zooms and pans. Strokes reuse
	[BrushTool]'s linear brush and stickers reuse [StickerTool]'s flat sticker action, so the model
	updates live and the server replays the same actions it already knows.

	It holds the window, zoom, pan, cursor and sticker handle as atoms for the `UVCanvasWindow` view
	to render, and reads pointer input off the instances that view hands it through `attach`. Once
	shown, the window keeps its size as panels open and close beside it. Owned by [CreationPanels].
]=]
local function UVCanvas(
	modelInfo: any,
	creationInput: any,
	brushTool: any,
	stickerTool: any,
	onCloseRequested: () -> ()
): UVCanvas
	local maid = Maid.new()
	local openMaid = maid:add(Maid.new())
	local attachMaid = maid:add(Maid.new())
	local object = {} :: UVCanvas

	local config = CreationConfig.uvCanvas

	object.modelInfo = modelInfo
	object.creationInput = creationInput
	object.brushTool = brushTool
	object.stickerTool = stickerTool
	object.mode = Charm.atom(nil :: UVCanvasMode?)
	object.stacks = Charm.atom({} :: { MeshPart })
	object.selectedStack = Charm.atom(nil :: MeshPart?)
	object.textureImage = Charm.atom(nil :: EditableImage?)
	object.cellSize = Charm.atom(Vector2.one)
	object.wireframeVisible = Charm.atom(true)
	object.wireframeImage = Charm.atom(nil :: EditableImage?)
	object.window = Charm.atom({ position = Vector2.zero, size = Vector2.zero } :: Rect)
	object.content = Charm.atom({ position = Vector2.zero, size = Vector2.zero, pixelated = false } :: ContentState)
	object.cursor = Charm.atom(HIDDEN_CURSOR)
	object.stickerHandle = Charm.atom(HIDDEN_HANDLE)
	object.maid = maid

	local refs: Refs? = nil
	local anchorPanel: GuiObject? = nil
	local windowPosition: Vector2? = nil
	local windowSize: Vector2? = nil
	local windowDragOrigin: Vector2? = nil
	local zoom = 1
	local pan = Vector2.zero
	local gesture: Gesture? = nil
	local gestureInputType: Enum.UserInputType? = nil
	local needsStrokeBegin = false
	local lastPointer: Vector2? = nil
	local touches: { InputObject } = {}
	local lastPinchDistance: number? = nil
	local wireframeMeshPart: MeshPart? = nil

	local function getTextureInfo(): TextureInfo.TextureInfo
		return modelInfo:getTextureInfo()
	end

	local function getStackParts(representative: MeshPart): { MeshPart }
		local textureInfo = getTextureInfo()
		local parts = {}

		for _, meshPart in modelInfo:getMeshParts() do
			if textureInfo.modelTextureInfo[meshPart] and textureInfo:meshPartsShareLayer(meshPart, representative) then
				table.insert(parts, meshPart)
			end
		end

		return parts
	end

	local function getSortedStacks(): { MeshPart }
		local stacks = {}
		for meshPart in getTextureInfo():getUniqueLayerMap() do
			table.insert(stacks, meshPart)
		end

		table.sort(stacks, function(a, b)
			return a.Name < b.Name
		end)

		return stacks
	end

	local function getOutputImage(meshPart: MeshPart): EditableImage
		return getTextureInfo().modelTextureInfo[meshPart].outputEditableImage
	end

	local function getCellSize(): Vector2
		local meshPart = assert(object.selectedStack(), "UVCanvas has no layer stack")

		return getTextureInfo():getTextureSize(meshPart)
	end

	local function isOverGui(gui: GuiObject, screenPos: Vector2): boolean
		local relative = screenPos - gui.AbsolutePosition
		local size = gui.AbsoluteSize

		return gui.Visible and relative.X >= 0 and relative.Y >= 0 and relative.X <= size.X and relative.Y <= size.Y
	end

	local function getBaseScale(): number
		local viewFrame = refs and refs.viewFrame
		if not viewFrame then
			return 1
		end

		local textureSize = object.cellSize()
		local viewportSize = viewFrame.AbsoluteSize

		return math.min(viewportSize.X / textureSize.X, viewportSize.Y / textureSize.Y)
	end

	local function getContentSize(): Vector2
		return object.cellSize() * getBaseScale() * zoom
	end

	local function applyView()
		object.content({
			position = pan,
			size = getContentSize(),
			pixelated = getBaseScale() * zoom >= config.pixelatedDisplayScale,
		})
	end

	local function containsPoint(screenPos: Vector2): boolean
		local viewFrame = refs and refs.viewFrame
		if not viewFrame or not object.mode() then
			return false
		end

		local relative = screenPos - viewFrame.AbsolutePosition
		local size = viewFrame.AbsoluteSize

		return relative.X >= 0 and relative.Y >= 0 and relative.X < size.X and relative.Y < size.Y
	end

	local function screenToLocal(screenPos: Vector2): Vector2?
		if not containsPoint(screenPos) then
			return nil
		end

		local contentSize = getContentSize()
		if contentSize.X <= 0 or contentSize.Y <= 0 then
			return nil
		end

		local contentPosition = (refs :: Refs).viewFrame.AbsolutePosition + pan
		local localPos = (screenPos - contentPosition) / contentSize
		if localPos.X < 0 or localPos.Y < 0 or localPos.X >= 1 or localPos.Y >= 1 then
			return nil
		end

		return localPos
	end

	local function localToOffset(localPos: Vector2): Vector2
		return localPos * getContentSize()
	end

	local function zoomAt(screenPos: Vector2, steps: number)
		local viewFrame = refs and refs.viewFrame
		if not viewFrame then
			return
		end

		local newZoom = math.clamp(zoom * config.zoomStepFactor ^ steps, config.minZoom, config.maxZoom)
		if newZoom == zoom then
			return
		end

		local anchor = screenPos - viewFrame.AbsolutePosition
		pan = anchor - (anchor - pan) * (newZoom / zoom)
		zoom = newZoom

		applyView()
	end

	local function panBy(delta: Vector2)
		pan += delta
		applyView()
	end

	local function setCursor(screenPos: Vector2?, diameter: number)
		if not screenPos or not containsPoint(screenPos) then
			object.cursor(HIDDEN_CURSOR)
			return
		end

		object.cursor({
			visible = true,
			position = screenPos - (refs :: Refs).viewFrame.AbsolutePosition,
			diameter = diameter,
		})
	end

	local function pointerToTexel(screenPos: Vector2): Vector2?
		local localPos = screenToLocal(screenPos)
		if not localPos then
			return nil
		end

		local texel = localPos * getCellSize()

		return Vector2.new(math.floor(texel.X), math.floor(texel.Y))
	end

	local function destroyWireframe()
		local wireframeImage = object.wireframeImage()
		if wireframeImage then
			wireframeImage:Destroy()
		end

		wireframeMeshPart = nil
		object.wireframeImage(nil)
	end

	local function rebuildWireframe()
		local meshPart = object.selectedStack()
		if not meshPart or wireframeMeshPart == meshPart then
			return
		end

		destroyWireframe()

		local cellSize = getCellSize()
		local ok, wireframeImage = pcall(function()
			return AssetService:CreateEditableImage({ Size = cellSize })
		end)
		if not ok or not wireframeImage then
			warn("UVCanvas could not allocate the UV wireframe image")
			return
		end

		wireframeMeshPart = meshPart
		object.wireframeImage(wireframeImage)

		local meshInfo = modelInfo:getMeshInfo()
		local editableMeshes = {}
		for _, stackPart in getStackParts(meshPart) do
			table.insert(editableMeshes, meshInfo:getEditableMesh(stackPart))
		end

		local thickness = math.max(1, math.round(cellSize.X * config.wireframeThicknessScale))
		task.spawn(function()
			UVWireframe.rasterize(
				editableMeshes,
				wireframeImage,
				getOutputImage(meshPart).Size,
				config.wireframeColor,
				0,
				thickness,
				config.wireframeFacesPerYield
			)
		end)
	end

	local function updateStickerPlacement()
		local viewFrame = refs and refs.viewFrame
		if object.mode() ~= "sticker" or not object.selectedStack() or not viewFrame then
			stickerTool:setCanvasPlacement(nil, nil)
			return
		end

		local viewCenter = viewFrame.AbsolutePosition + viewFrame.AbsoluteSize / 2
		local texel = pointerToTexel(viewCenter) or getCellSize() / 2

		stickerTool:setCanvasPlacement(object:resolvePaintTarget(texel) or object.selectedStack(), texel)
	end

	local function getCanvasSticker(): any?
		local sticker = stickerTool:getSelectedSticker()
		local selectedStack = object.selectedStack()
		if
			not sticker
			or not sticker.isTextureSpace
			or not selectedStack
			or not getTextureInfo():meshPartsShareLayer(sticker.targetMeshPart, selectedStack)
		then
			return nil
		end

		return sticker
	end

	local function getStickerScreenPosition(sticker: any): Vector2
		local contentPosition = (refs :: Refs).viewFrame.AbsolutePosition + pan

		return contentPosition + localToOffset(sticker.texturePosition / getCellSize())
	end

	local function refreshStickerHandle()
		local sticker = if object.mode() == "sticker" then getCanvasSticker() else nil
		if not sticker then
			if object.stickerHandle().visible then
				object.stickerHandle(HIDDEN_HANDLE)
			end
			return
		end

		object.stickerHandle({
			visible = true,
			offset = localToOffset(sticker.texturePosition / getCellSize()),
			scale = sticker.scale,
			rotation = sticker.rotation,
		})
	end

	local function selectStickerAt(screenPos: Vector2): boolean
		local textureInfo = getTextureInfo()
		local closestIndex, closestDistance = nil, math.huge

		for index, sticker in stickerTool.appliedStickers do
			if
				sticker.isTextureSpace
				and textureInfo:meshPartsShareLayer(sticker.targetMeshPart, object.selectedStack())
			then
				local distance = (getStickerScreenPosition(sticker) - screenPos).Magnitude
				if distance < closestDistance then
					closestIndex, closestDistance = index, distance
				end
			end
		end

		if not closestIndex or closestDistance > config.stickerHitRadius then
			return false
		end

		stickerTool:selectSticker(closestIndex)

		return true
	end

	local function layout()
		local container = refs and refs.container
		local parent = container and container.Parent
		if not object.mode() or not parent or not parent:IsA("GuiBase2d") then
			return
		end

		local viewportSize = parent.AbsoluteSize
		local right = if anchorPanel
			then anchorPanel.AbsolutePosition.X - parent.AbsolutePosition.X - config.panelGap
			else viewportSize.X - config.panelGap
		local left = viewportSize.X * config.modelScreenXScale * 2
		local defaultSide = math.min(viewportSize.Y * config.heightScale, right - left)

		local size = windowSize or Vector2.new(defaultSide, defaultSide)
		size = Vector2.new(
			math.clamp(size.X, config.minWindowSize, math.max(viewportSize.X, config.minWindowSize)),
			math.clamp(size.Y, config.minWindowSize, math.max(viewportSize.Y, config.minWindowSize))
		)
		windowSize = size

		local position = windowPosition or Vector2.new(right - size.X, (viewportSize.Y - size.Y) / 2)
		position = Vector2.new(
			math.clamp(position.X, 0, math.max(viewportSize.X - size.X, 0)),
			math.clamp(position.Y, 0, math.max(viewportSize.Y - size.Y, 0))
		)

		object.window({ position = position, size = size })
	end

	local function paintAt(screenPos: Vector2)
		local texel = pointerToTexel(screenPos)
		local meshPart = if texel then object:resolvePaintTarget(texel) else nil
		if not texel or not meshPart then
			brushTool:endStroke()
			needsStrokeBegin = true
			return
		end

		local drawInfo: Brushes.DrawInfo = {
			textureDrawPosition = texel,
			cameraCFrame = workspace.CurrentCamera.CFrame,
			castedPoint = Vector3.zero,
			isVirtualCursorMovement = false,
			alwaysConnect = true,
		}

		if needsStrokeBegin then
			needsStrokeBegin = false
			brushTool:beginStroke(meshPart, drawInfo, true)
		else
			brushTool:continueStroke(meshPart, drawInfo)
		end
	end

	local function updateCursor(screenPos: Vector2?)
		if object.mode() ~= "paint" then
			setCursor(nil, 0)
			return
		end

		local diameter = 2 * brushTool:getActiveSize() * (getContentSize().X / object.cellSize().X)
		setCursor(screenPos, diameter)
	end

	local function endGesture()
		if gesture == "paint" then
			brushTool:endStroke()
		elseif gesture == "moveSticker" or gesture == "rotateSticker" or gesture == "scaleSticker" then
			stickerTool:commitStickerEdit()
		end

		gesture = nil
		gestureInputType = nil
		lastPointer = nil
		lastPinchDistance = nil
		windowDragOrigin = nil
	end

	local function beginPointerGesture(screenPos: Vector2)
		local mode = object.mode()
		if mode == "view" then
			gesture = "pan"
			return
		end

		if mode == "paint" then
			gesture = "paint"
			needsStrokeBegin = true
			paintAt(screenPos)
			return
		end

		local sticker = getCanvasSticker()
		local currentRefs = refs :: Refs
		if sticker and isOverGui(currentRefs.rotateHandle, screenPos) then
			gesture = "rotateSticker"
		elseif sticker and isOverGui(currentRefs.scaleHandle, screenPos) then
			gesture = "scaleSticker"
		elseif selectStickerAt(screenPos) then
			gesture = "moveSticker"
		end
	end

	local function continueStickerGesture(screenPos: Vector2)
		local sticker = getCanvasSticker()
		if not sticker then
			return
		end

		if gesture == "moveSticker" then
			local texel = pointerToTexel(screenPos)
			local meshPart = if texel then object:resolvePaintTarget(texel) or sticker.targetMeshPart else nil
			if texel and meshPart then
				stickerTool:moveSelectedStickerTo(meshPart, texel)
			end
		elseif gesture == "rotateSticker" then
			local fromCenter = screenPos - getStickerScreenPosition(sticker)
			local pointerDegrees = math.deg(math.atan2(fromCenter.Y, fromCenter.X))
			local rotation = (pointerDegrees + StyleTokens.style.RotateHandlePosDegrees) % 360 - 360

			stickerTool:setSelectedStickerTransform(rotation, nil)
		elseif gesture == "scaleSticker" and lastPointer then
			local scaleChange = (screenPos - lastPointer).X * CreationConfig.scaleDragSensitivity
			if sticker.rotation < -135 and sticker.rotation >= -315 then
				scaleChange *= -1
			end

			stickerTool:setSelectedStickerTransform(nil, sticker.scale + scaleChange)
		end
	end

	local function onPointerMoved(screenPos: Vector2)
		if gesture == "paint" then
			paintAt(screenPos)
		elseif gesture == "pan" and lastPointer then
			panBy(screenPos - lastPointer)
			updateStickerPlacement()
		elseif gesture == "moveWindow" and lastPointer and windowDragOrigin then
			windowPosition = windowDragOrigin + (screenPos - lastPointer)
			layout()
			return
		elseif gesture == "resizeWindow" and lastPointer and windowDragOrigin then
			windowSize = windowDragOrigin + (screenPos - lastPointer)
			layout()
			return
		elseif gesture then
			continueStickerGesture(screenPos)
		end

		lastPointer = screenPos
		updateCursor(screenPos)
	end

	local function onPinchMoved()
		local first, second = touches[1], touches[2]
		if not first or not second then
			return
		end

		local a = ToolInput.getGuiPosition(first)
		local b = ToolInput.getGuiPosition(second)
		local midpoint = (a + b) / 2
		local distance = (a - b).Magnitude

		if lastPinchDistance and lastPointer then
			local steps = (distance - lastPinchDistance) / config.pinchZoomPixelsPerStep
			panBy(midpoint - lastPointer)
			zoomAt(midpoint, steps)
			updateStickerPlacement()
		end

		lastPinchDistance = distance
		lastPointer = midpoint
	end

	local function removeTouch(input: InputObject)
		local index = table.find(touches, input)
		if index then
			table.remove(touches, index)
		end
	end

	local function beginWindowGesture(input: InputObject, windowGesture: Gesture)
		if not object.mode() or not ToolInput.isValidSelectingInput(input) or gesture then
			return
		end

		if not creationInput:tryGrabLock(object) then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			table.insert(touches, input)
		end

		local window = object.window()
		gesture = windowGesture
		gestureInputType = input.UserInputType
		lastPointer = ToolInput.getGuiPosition(input)

		if windowGesture == "resizeWindow" then
			windowPosition = window.position
			windowDragOrigin = window.size
		else
			windowDragOrigin = window.position
		end
	end

	local function onViewInputBegan(input: InputObject)
		local inputType = input.UserInputType
		local isTouch = inputType == Enum.UserInputType.Touch
		if
			not object.mode()
			or (
				not isTouch
				and inputType ~= Enum.UserInputType.MouseButton1
				and inputType ~= Enum.UserInputType.MouseButton2
			)
		then
			return
		end

		if isTouch then
			table.insert(touches, input)
			if #touches == 2 then
				endGesture()
				gesture = "pinch"
				return
			elseif #touches > 2 then
				return
			end
		end

		local screenPos = ToolInput.getGuiPosition(input)
		if isOverGui((refs :: Refs).resizeGrip, screenPos) then
			return
		end

		if gesture or not creationInput:tryGrabLock(object) then
			return
		end

		lastPointer = screenPos
		gestureInputType = inputType

		if inputType == Enum.UserInputType.MouseButton2 then
			gesture = "pan"
		else
			beginPointerGesture(screenPos)
		end
	end

	local function connectOpenInput()
		openMaid:add(UserInputService.InputChanged:Connect(function(input)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseMovement then
				onPointerMoved(ToolInput.getGuiPosition(input))
			elseif inputType == Enum.UserInputType.Touch and table.find(touches, input) then
				if gesture == "pinch" then
					onPinchMoved()
				elseif touches[1] == input then
					onPointerMoved(ToolInput.getGuiPosition(input))
				end
			end
		end))

		openMaid:add(UserInputService.InputEnded:Connect(function(input)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.Touch then
				if not table.find(touches, input) then
					return
				end

				removeTouch(input)
				if #touches == 0 or gesture ~= "pinch" then
					endGesture()
				end
			elseif inputType == gestureInputType then
				endGesture()
			end
		end))

		openMaid:add(RunService.RenderStepped:Connect(refreshStickerHandle))
	end

	local function refreshStacks()
		local stacks = getSortedStacks()
		object.stacks(if #stacks > 1 then stacks else {})
	end

	local function getDefaultStack(): MeshPart?
		local lastDrawn = brushTool.lastDrawnMeshPart
		if lastDrawn and lastDrawn.Parent and getTextureInfo().modelTextureInfo[lastDrawn] then
			return lastDrawn
		end

		return modelInfo:getMeshPartByName("Head") or getSortedStacks()[1]
	end

	--[=[
		@within UVCanvas
		@param mode UVCanvasMode -- whether the canvas paints, edits stickers or only shows the texture
		@param anchor GuiObject? -- the open tool panel the canvas sits beside, or nil for the screen edge

		Opens the canvas, or switches an open canvas to a new mode while keeping its layer stack,
		zoom and pan.
	]=]
	function object:open(mode: UVCanvasMode, anchor: GuiObject?)
		local wasOpen = self:isOpen()

		endGesture()
		self.mode(mode)
		anchorPanel = anchor

		openMaid.anchorMoved = if anchor
			then anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
			else nil

		if not wasOpen then
			connectOpenInput()
		end

		layout()

		if not wasOpen then
			local defaultStack = getDefaultStack()
			if defaultStack then
				self:selectLayerStack(defaultStack)
			end

			refreshStacks()
		end

		updateStickerPlacement()
		updateCursor(nil)
	end

	--[=[
		@within UVCanvas

		Hides the canvas, ends any gesture in progress and frees the wireframe image.
	]=]
	function object:close()
		if not self.mode() then
			return
		end

		endGesture()
		table.clear(touches)
		openMaid:doCleaning()

		stickerTool:setCanvasPlacement(nil, nil)
		destroyWireframe()

		self.mode(nil)
		anchorPanel = nil
		self.cursor(HIDDEN_CURSOR)
		self.stickerHandle(HIDDEN_HANDLE)
	end

	--[=[
		@within UVCanvas
		@return boolean -- true while the canvas is showing
	]=]
	function object:isOpen(): boolean
		return self.mode() ~= nil
	end

	--[=[
		@within UVCanvas
		@param meshPart MeshPart -- any part of the layer stack to show

		Shows that stack's texture, fitted to the window.
	]=]
	function object:selectLayerStack(meshPart: MeshPart)
		endGesture()

		self.selectedStack(meshPart)
		self.textureImage(getOutputImage(meshPart))
		self.cellSize(getCellSize())
		self:resetView()

		destroyWireframe()
		if self.wireframeVisible() then
			rebuildWireframe()
		end

		updateStickerPlacement()
	end

	--[=[
		@within UVCanvas
		@param isVisible boolean -- whether the UV wireframe overlay shows; built on first show
	]=]
	function object:setWireframeVisible(isVisible: boolean)
		self.wireframeVisible(isVisible)

		if isVisible and self:isOpen() then
			rebuildWireframe()
		end
	end

	--[=[
		@within UVCanvas

		Fits the whole texture in the window, centred.
	]=]
	function object:resetView()
		local viewFrame = refs and refs.viewFrame
		zoom = 1

		if viewFrame then
			pan = (viewFrame.AbsoluteSize - self.cellSize() * getBaseScale()) / 2
		end

		applyView()
	end

	--[=[
		@within UVCanvas

		Asks the owner to turn the canvas off, as the header's close button does.
	]=]
	function object:requestClose()
		onCloseRequested()
	end

	--[=[
		@within UVCanvas
		@param texel Vector2 -- a texel on the selected layer stack
		@return MeshPart? -- the part whose region owns the texel, or nil when none does

		Parts sharing one layer stack each stencil to their own region, so a stroke has to target
		the part that owns the texel under the pointer.
	]=]
	function object:resolvePaintTarget(texel: Vector2): MeshPart?
		local selectedMeshPart = self.selectedStack()
		if not selectedMeshPart then
			return nil
		end

		local textureInfo = getTextureInfo()
		local hasAnyRegion = false

		for _, meshPart in getStackParts(selectedMeshPart) do
			local region = textureInfo:getMeshPartRegion(meshPart.Name)
			if region then
				hasAnyRegion = true
				if TextureUtils.regionContainsPixel(region, texel) then
					return meshPart
				end
			end
		end

		return if hasAnyRegion then nil else selectedMeshPart
	end

	--[=[
		@within UVCanvas
		@param newRefs Refs? -- the rendered window's instances, or nil once it unmounts

		Connects pointer input to the rendered window and measures against it.
	]=]
	function object:attach(newRefs: Refs?)
		attachMaid:doCleaning()
		refs = newRefs

		if not newRefs then
			return
		end

		local viewFrame = newRefs.viewFrame
		local parent = newRefs.container.Parent

		attachMaid:add(newRefs.container.InputBegan:Connect(function(input)
			beginWindowGesture(input, "moveWindow")
		end))
		attachMaid:add(newRefs.resizeGrip.InputBegan:Connect(function(input)
			beginWindowGesture(input, "resizeWindow")
		end))
		attachMaid:add(viewFrame.InputBegan:Connect(onViewInputBegan))
		attachMaid:add(viewFrame.InputChanged:Connect(function(input)
			if object.mode() and input.UserInputType == Enum.UserInputType.MouseWheel then
				local pointer = ToolInput.getGuiPosition(input)
				zoomAt(pointer, input.Position.Z)
				updateStickerPlacement()
				updateCursor(pointer)
			end
		end))
		attachMaid:add(viewFrame.MouseLeave:Connect(function()
			if not gesture then
				setCursor(nil, 0)
			end
		end))
		attachMaid:add(viewFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if zoom == 1 then
				object:resetView()
			else
				applyView()
			end
		end))
		if parent and parent:IsA("GuiBase2d") then
			attachMaid:add(parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
		end

		layout()
		object:resetView()
	end

	function object:destroy()
		self:close()
		maid:doCleaning()
	end

	return object
end

return UVCanvas

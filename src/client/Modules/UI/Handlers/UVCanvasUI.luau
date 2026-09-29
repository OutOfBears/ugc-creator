local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Brushes = require(ReplicatedStorage.Shared.Modules.Brushes)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local EditHandle = require("../Components/EditHandle")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local SegmentedControl = require("../Components/SegmentedControl")
local StyleConsts = require("../Style/StyleConsts")
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local StyleUtils = require("../Style/StyleUtils")
local TextButton = require("../Components/TextButton")
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)
local TextureUtils = require(ReplicatedStorage.Shared.Modules.Utils.TextureUtils)
local ToggleButton = require("../Components/ToggleButton")
local ToolInput = require("../../ToolInput")
local UVCanvasView = require("../Components/UVCanvasView")
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

export type UVCanvasUI = {
	-- vars
	session: any,
	modelInfo: any,
	creationInput: any,
	brushTool: any,
	stickerTool: any,
	container: Frame,
	header: Frame,
	view: UVCanvasView.UVCanvasView,
	stickerHandle: EditHandle.EditHandle,
	stackSelector: SegmentedControl.SegmentedControl?,
	mode: UVCanvasMode?,
	anchorPanel: GuiObject?,
	windowPosition: Vector2?,
	windowSize: Vector2?,
	windowDragOrigin: Vector2?,
	resizeGrip: TextButton,
	selectedMeshPart: MeshPart?,
	isWireframeVisible: boolean,
	wireframeImage: EditableImage?,
	wireframeMeshPart: MeshPart?,
	gesture: Gesture?,
	gestureInputType: Enum.UserInputType?,
	needsStrokeBegin: boolean,
	lastPointer: Vector2?,
	touches: { InputObject },
	lastPinchDistance: number?,
	openMaid: Maid.Maid,
	maid: Maid.Maid,
	-- methods
	open: (self: UVCanvasUI, mode: UVCanvasMode, anchorPanel: GuiObject?) -> (),
	close: (self: UVCanvasUI) -> (),
	isOpen: (self: UVCanvasUI) -> boolean,
	selectLayerStack: (self: UVCanvasUI, meshPart: MeshPart) -> (),
	setWireframeVisible: (self: UVCanvasUI, isVisible: boolean) -> (),
	resolvePaintTarget: (self: UVCanvasUI, texel: Vector2) -> MeshPart?,
	destroy: (self: UVCanvasUI) -> (),
}

--[=[
	@class UVCanvasUI
	@client

	The 2D canvas: a movable, resizable window showing a layer stack's texture flat in UV space.
	Every tool can show it; in `paint` and `sticker` modes the player also paints, erases and places
	stickers on it directly, while `view` mode only zooms and pans. Strokes reuse [BrushTool]'s linear brush
	and stickers reuse [StickerTool]'s flat sticker action, so the model updates live and the server
	replays the same actions it already knows. Owned by [CreationPanels].
]=]
local function UVCanvasUI(
	session: any,
	modelInfo: any,
	creationInput: any,
	brushTool: any,
	stickerTool: any
): UVCanvasUI
	local maid = Maid.new()
	local object = {} :: UVCanvasUI

	object.session = session
	object.modelInfo = modelInfo
	object.creationInput = creationInput
	object.brushTool = brushTool
	object.stickerTool = stickerTool

	object.mode = nil
	object.anchorPanel = nil
	object.windowPosition = nil
	object.windowSize = nil
	object.windowDragOrigin = nil
	object.selectedMeshPart = nil
	object.isWireframeVisible = true
	object.wireframeImage = nil
	object.wireframeMeshPart = nil
	object.gesture = nil
	object.gestureInputType = nil
	object.needsStrokeBegin = false
	object.lastPointer = nil
	object.touches = {}
	object.lastPinchDistance = nil

	object.maid = maid
	object.openMaid = maid:add(Maid.new())

	object.view = maid:add(UVCanvasView())
	object.view:setWireframeVisible(object.isWireframeVisible)
	object.view.frame.LayoutOrder = 2

	object.header = Create("Frame", {
		Name = "Header",
		LayoutOrder = 1,
		Tags = { StyleConsts.tags.UVCanvasHeader },
	}) :: Frame

	object.container = maid:add(Create("Frame", {
		Name = "UVCanvasContainer",
		Active = true,
		Visible = false,
		Tags = { StyleConsts.tags.UVCanvasContainer },
		Children = { object.header, object.view.frame },
	}) :: Frame)

	object.resizeGrip = Create("TextButton", {
		Name = "ResizeGrip",
		Text = "◢",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Tags = { StyleConsts.tags.UVCanvasResizeGrip },
		Parent = object.view.frame,
	}) :: TextButton

	object.stickerHandle = maid:add(EditHandle())
	object.stickerHandle.moveHandle.Interactable = false
	object.stickerHandle.moveHandle.Visible = false
	object.stickerHandle.moveHandle.Parent = object.view.handleParent

	local wireframeToggle = ToggleButton({
		label = CreationStrings.uvWireframeToggle,
		initialOn = true,
		callback = function(isOn)
			object:setWireframeVisible(isOn)
		end,
	})
	wireframeToggle.LayoutOrder = 1
	StyleUtils.addStyleTag(wireframeToggle, StyleConsts.tags.ToggleFrameLeft)
	wireframeToggle.Parent = object.header

	local resetButton = TextButton({
		text = CreationStrings.uvCanvasResetView,
		callback = function()
			object.view:resetView()
		end,
	})
	resetButton.LayoutOrder = 3
	StyleUtils.addStyleTag(resetButton, StyleConsts.tags.UVCanvasHeaderButton)
	resetButton.Parent = object.header

	local function getTextureInfo(): TextureInfo.TextureInfo
		return object.modelInfo:getTextureInfo()
	end

	local function getStackParts(representative: MeshPart): { MeshPart }
		local textureInfo = getTextureInfo()
		local parts = {}

		for _, meshPart in object.modelInfo:getMeshParts() do
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
		local meshPart = assert(object.selectedMeshPart, "UVCanvasUI has no layer stack")

		return getTextureInfo():getTextureSize(meshPart)
	end

	local function pointerToTexel(screenPos: Vector2): Vector2?
		local localPos = object.view:screenToLocal(screenPos)
		if not localPos then
			return nil
		end

		local texel = localPos * getCellSize()

		return Vector2.new(math.floor(texel.X), math.floor(texel.Y))
	end

	local function destroyWireframe()
		if object.wireframeImage then
			object.wireframeImage:Destroy()
		end

		object.wireframeImage = nil
		object.wireframeMeshPart = nil
		object.view:setWireframe(nil)
	end

	local function rebuildWireframe()
		local meshPart = object.selectedMeshPart
		if not meshPart or object.wireframeMeshPart == meshPart then
			return
		end

		destroyWireframe()

		local cellSize = getCellSize()
		local ok, wireframeImage = pcall(function()
			return AssetService:CreateEditableImage({ Size = cellSize })
		end)
		if not ok or not wireframeImage then
			warn("UVCanvasUI could not allocate the UV wireframe image")
			return
		end

		object.wireframeImage = wireframeImage
		object.wireframeMeshPart = meshPart
		object.view:setWireframe(wireframeImage)

		local meshInfo = object.modelInfo:getMeshInfo()
		local editableMeshes = {}
		for _, stackPart in getStackParts(meshPart) do
			table.insert(editableMeshes, meshInfo:getEditableMesh(stackPart))
		end

		local config = CreationConfig.uvCanvas
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
		if object.mode ~= "sticker" or not object.selectedMeshPart then
			object.stickerTool:setCanvasPlacement(nil, nil)
			return
		end

		local viewCenter = object.view.frame.AbsolutePosition + object.view.frame.AbsoluteSize / 2
		local texel = pointerToTexel(viewCenter) or getCellSize() / 2

		object.stickerTool:setCanvasPlacement(object:resolvePaintTarget(texel) or object.selectedMeshPart, texel)
	end

	local function getCanvasSticker(): any?
		local sticker = object.stickerTool:getSelectedSticker()
		if
			not sticker
			or not sticker.isTextureSpace
			or not object.selectedMeshPart
			or not getTextureInfo():meshPartsShareLayer(sticker.targetMeshPart, object.selectedMeshPart)
		then
			return nil
		end

		return sticker
	end

	local function getStickerScreenPosition(sticker: any): Vector2
		return object.view.content.AbsolutePosition + object.view:localToOffset(sticker.texturePosition / getCellSize())
	end

	local function refreshStickerHandle()
		local moveHandle = object.stickerHandle.moveHandle
		local sticker = if object.mode == "sticker" then getCanvasSticker() else nil
		if not sticker then
			moveHandle.Visible = false
			return
		end

		local offset = object.view:localToOffset(sticker.texturePosition / getCellSize())
		object.stickerHandle:refresh(offset, sticker.scale, sticker.rotation)
		moveHandle.Visible = true
	end

	local function isOverGui(gui: GuiObject, screenPos: Vector2): boolean
		local relative = screenPos - gui.AbsolutePosition
		local size = gui.AbsoluteSize

		return gui.Visible and relative.X >= 0 and relative.Y >= 0 and relative.X <= size.X and relative.Y <= size.Y
	end

	local function selectStickerAt(screenPos: Vector2): boolean
		local textureInfo = getTextureInfo()
		local hitRadius = CreationConfig.uvCanvas.stickerHitRadius
		local closestIndex, closestDistance = nil, math.huge

		for index, sticker in object.stickerTool.appliedStickers do
			if
				sticker.isTextureSpace
				and textureInfo:meshPartsShareLayer(sticker.targetMeshPart, object.selectedMeshPart)
			then
				local distance = (getStickerScreenPosition(sticker) - screenPos).Magnitude
				if distance < closestDistance then
					closestIndex, closestDistance = index, distance
				end
			end
		end

		if not closestIndex or closestDistance > hitRadius then
			return false
		end

		object.stickerTool:selectSticker(closestIndex)

		return true
	end

	local function layout()
		local parent = object.container.Parent
		if not object.mode or not parent or not parent:IsA("GuiBase2d") then
			return
		end

		local config = CreationConfig.uvCanvas
		local viewportSize = parent.AbsoluteSize
		local anchor = object.anchorPanel
		local right = if anchor
			then anchor.AbsolutePosition.X - parent.AbsolutePosition.X - config.panelGap
			else viewportSize.X - config.panelGap
		local left = viewportSize.X * config.modelScreenXScale * 2
		local defaultSide = math.min(viewportSize.Y * config.heightScale, right - left)

		local size = object.windowSize or Vector2.new(defaultSide, defaultSide)
		size = Vector2.new(
			math.clamp(size.X, config.minWindowSize, math.max(viewportSize.X, config.minWindowSize)),
			math.clamp(size.Y, config.minWindowSize, math.max(viewportSize.Y, config.minWindowSize))
		)

		local position = object.windowPosition or Vector2.new(right - size.X, (viewportSize.Y - size.Y) / 2)
		position = Vector2.new(
			math.clamp(position.X, 0, math.max(viewportSize.X - size.X, 0)),
			math.clamp(position.Y, 0, math.max(viewportSize.Y - size.Y, 0))
		)

		object.container.Position = UDim2.fromOffset(position.X, position.Y)
		object.container.Size = UDim2.fromOffset(size.X, size.Y)
	end

	local function paintAt(screenPos: Vector2)
		local texel = pointerToTexel(screenPos)
		local meshPart = if texel then object:resolvePaintTarget(texel) else nil
		if not texel or not meshPart then
			object.brushTool:endStroke()
			object.needsStrokeBegin = true
			return
		end

		local drawInfo: Brushes.DrawInfo = {
			textureDrawPosition = texel,
			cameraCFrame = workspace.CurrentCamera.CFrame,
			castedPoint = Vector3.zero,
			isVirtualCursorMovement = false,
			alwaysConnect = true,
		}

		if object.needsStrokeBegin then
			object.needsStrokeBegin = false
			object.brushTool:beginStroke(meshPart, drawInfo, true)
		else
			object.brushTool:continueStroke(meshPart, drawInfo)
		end
	end

	local function updateCursor(screenPos: Vector2?)
		if object.mode ~= "paint" then
			object.view:setCursor(nil, 0)
			return
		end

		local diameter = 2 * object.brushTool:getActiveSize() * object.view:getDisplayScale()
		object.view:setCursor(screenPos, diameter)
	end

	local function endGesture()
		if object.gesture == "paint" then
			object.brushTool:endStroke()
		elseif
			object.gesture == "moveSticker"
			or object.gesture == "rotateSticker"
			or object.gesture == "scaleSticker"
		then
			object.stickerTool:commitStickerEdit()
		end

		object.gesture = nil
		object.gestureInputType = nil
		object.lastPointer = nil
		object.lastPinchDistance = nil
		object.windowDragOrigin = nil
	end

	local function beginPointerGesture(screenPos: Vector2)
		if object.mode == "view" then
			object.gesture = "pan"
			return
		end

		if object.mode == "paint" then
			object.gesture = "paint"
			object.needsStrokeBegin = true
			paintAt(screenPos)
			return
		end

		local sticker = getCanvasSticker()
		if sticker and isOverGui(object.stickerHandle.rotateHandle, screenPos) then
			object.gesture = "rotateSticker"
		elseif sticker and isOverGui(object.stickerHandle.scaleHandle, screenPos) then
			object.gesture = "scaleSticker"
		elseif selectStickerAt(screenPos) then
			object.gesture = "moveSticker"
		end
	end

	local function continueStickerGesture(screenPos: Vector2)
		local sticker = getCanvasSticker()
		if not sticker then
			return
		end

		if object.gesture == "moveSticker" then
			local texel = pointerToTexel(screenPos)
			local meshPart = if texel then object:resolvePaintTarget(texel) or sticker.targetMeshPart else nil
			if texel and meshPart then
				object.stickerTool:moveSelectedStickerTo(meshPart, texel)
			end
		elseif object.gesture == "rotateSticker" then
			local fromCenter = screenPos - getStickerScreenPosition(sticker)
			local pointerDegrees = math.deg(math.atan2(fromCenter.Y, fromCenter.X))
			local rotation = (pointerDegrees + StyleTokens.style.RotateHandlePosDegrees) % 360 - 360

			object.stickerTool:setSelectedStickerTransform(rotation, nil)
		elseif object.gesture == "scaleSticker" and object.lastPointer then
			local scaleChange = (screenPos - object.lastPointer).X * CreationConfig.scaleDragSensitivity
			if sticker.rotation < -135 and sticker.rotation >= -315 then
				scaleChange *= -1
			end

			object.stickerTool:setSelectedStickerTransform(nil, sticker.scale + scaleChange)
		end
	end

	local function onPointerMoved(screenPos: Vector2)
		local gesture = object.gesture

		if gesture == "paint" then
			paintAt(screenPos)
		elseif gesture == "pan" and object.lastPointer then
			object.view:panBy(screenPos - object.lastPointer)
			updateStickerPlacement()
		elseif gesture == "moveWindow" and object.lastPointer and object.windowDragOrigin then
			object.windowPosition = object.windowDragOrigin + (screenPos - object.lastPointer)
			layout()
			return
		elseif gesture == "resizeWindow" and object.lastPointer and object.windowDragOrigin then
			object.windowSize = object.windowDragOrigin + (screenPos - object.lastPointer)
			layout()
			return
		elseif gesture then
			continueStickerGesture(screenPos)
		end

		object.lastPointer = screenPos
		updateCursor(screenPos)
	end

	local function onPinchMoved()
		local first, second = object.touches[1], object.touches[2]
		if not first or not second then
			return
		end

		local a = ToolInput.getGuiPosition(first)
		local b = ToolInput.getGuiPosition(second)
		local midpoint = (a + b) / 2
		local distance = (a - b).Magnitude

		if object.lastPinchDistance and object.lastPointer then
			local steps = (distance - object.lastPinchDistance) / CreationConfig.uvCanvas.pinchZoomPixelsPerStep
			object.view:panBy(midpoint - object.lastPointer)
			object.view:zoomAt(midpoint, steps)
			updateStickerPlacement()
		end

		object.lastPinchDistance = distance
		object.lastPointer = midpoint
	end

	local function removeTouch(input: InputObject)
		local index = table.find(object.touches, input)
		if index then
			table.remove(object.touches, index)
		end
	end

	local function connectInput(openMaid: Maid.Maid)
		local frame = object.view.frame

		openMaid:add(object.container.InputBegan:Connect(function(input)
			if not ToolInput.isValidSelectingInput(input) or object.gesture then
				return
			end

			if not object.creationInput:tryGrabLock(object) then
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				table.insert(object.touches, input)
			end

			local parent = object.container.Parent :: GuiObject
			object.gesture = "moveWindow"
			object.gestureInputType = input.UserInputType
			object.lastPointer = ToolInput.getGuiPosition(input)
			object.windowDragOrigin = object.container.AbsolutePosition - parent.AbsolutePosition
		end))

		openMaid:add(object.resizeGrip.InputBegan:Connect(function(input)
			if not ToolInput.isValidSelectingInput(input) or object.gesture then
				return
			end

			if not object.creationInput:tryGrabLock(object) then
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				table.insert(object.touches, input)
			end

			local parent = object.container.Parent :: GuiObject
			object.windowPosition = object.container.AbsolutePosition - parent.AbsolutePosition
			object.gesture = "resizeWindow"
			object.gestureInputType = input.UserInputType
			object.lastPointer = ToolInput.getGuiPosition(input)
			object.windowDragOrigin = object.container.AbsoluteSize
		end))

		openMaid:add(frame.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			local isTouch = inputType == Enum.UserInputType.Touch
			if
				not isTouch
				and inputType ~= Enum.UserInputType.MouseButton1
				and inputType ~= Enum.UserInputType.MouseButton2
			then
				return
			end

			if isTouch then
				table.insert(object.touches, input)
				if #object.touches == 2 then
					endGesture()
					object.gesture = "pinch"
					return
				elseif #object.touches > 2 then
					return
				end
			end

			local screenPos = ToolInput.getGuiPosition(input)
			if isOverGui(object.resizeGrip, screenPos) then
				return
			end

			if object.gesture or not object.creationInput:tryGrabLock(object) then
				return
			end

			object.lastPointer = screenPos
			object.gestureInputType = inputType

			if inputType == Enum.UserInputType.MouseButton2 then
				object.gesture = "pan"
			else
				beginPointerGesture(screenPos)
			end
		end))

		openMaid:add(frame.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local pointer = ToolInput.getGuiPosition(input)
				object.view:zoomAt(pointer, input.Position.Z)
				updateStickerPlacement()
				updateCursor(pointer)
			end
		end))

		openMaid:add(frame.MouseLeave:Connect(function()
			if not object.gesture then
				object.view:setCursor(nil, 0)
			end
		end))

		openMaid:add(UserInputService.InputChanged:Connect(function(input)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseMovement then
				onPointerMoved(ToolInput.getGuiPosition(input))
			elseif inputType == Enum.UserInputType.Touch and table.find(object.touches, input) then
				if object.gesture == "pinch" then
					onPinchMoved()
				elseif object.touches[1] == input then
					onPointerMoved(ToolInput.getGuiPosition(input))
				end
			end
		end))

		openMaid:add(UserInputService.InputEnded:Connect(function(input)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.Touch then
				if not table.find(object.touches, input) then
					return
				end

				removeTouch(input)
				if #object.touches == 0 or object.gesture ~= "pinch" then
					endGesture()
				end
			elseif inputType == object.gestureInputType then
				endGesture()
			end
		end))

		openMaid:add(RunService.RenderStepped:Connect(refreshStickerHandle))
	end

	local function rebuildStackSelector()
		if object.stackSelector then
			object.stackSelector:destroy()
			object.stackSelector = nil
		end

		local stacks = getSortedStacks()
		if #stacks <= 1 then
			return
		end

		local buttonInfos = {}
		for _, meshPart in stacks do
			table.insert(buttonInfos, {
				text = meshPart.Name,
				callback = function()
					object:selectLayerStack(meshPart)
				end,
			})
		end

		local stackSelector = SegmentedControl(buttonInfos)
		stackSelector.frame.LayoutOrder = 2
		stackSelector.frame.Parent = object.header
		object.stackSelector = stackSelector

		local textureInfo = getTextureInfo()
		for index, meshPart in stacks do
			if object.selectedMeshPart and textureInfo:meshPartsShareLayer(meshPart, object.selectedMeshPart) then
				stackSelector:applySelection(index)
				break
			end
		end
	end

	local function getDefaultStack(): MeshPart?
		local lastDrawn = object.brushTool.lastDrawnMeshPart
		if lastDrawn and lastDrawn.Parent and getTextureInfo().modelTextureInfo[lastDrawn] then
			return lastDrawn
		end

		return object.modelInfo:getMeshPartByName("Head") or getSortedStacks()[1]
	end

	--[=[
		@within UVCanvasUI
		@param mode UVCanvasMode -- whether the canvas paints, edits stickers or only shows the texture
		@param anchorPanel GuiObject? -- the open tool panel the canvas sits beside, or nil for the screen edge

		Opens the canvas, or switches an open canvas to a new mode while keeping its layer stack,
		zoom and pan.
	]=]
	function object:open(mode: UVCanvasMode, anchorPanel: GuiObject?)
		local wasOpen = self:isOpen()

		endGesture()
		self.mode = mode
		self.anchorPanel = anchorPanel

		local openMaid = self.openMaid
		openMaid.anchorMoved = if anchorPanel
			then anchorPanel:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
			else nil

		if not wasOpen then
			local parent = self.container.Parent
			if parent and parent:IsA("GuiBase2d") then
				openMaid:add(parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
			end

			connectInput(openMaid)
			self.container.Visible = true
		end

		layout()

		if not wasOpen then
			local defaultStack = getDefaultStack()
			if defaultStack then
				self:selectLayerStack(defaultStack)
			end

			rebuildStackSelector()
		end

		updateStickerPlacement()
		updateCursor(nil)

		self.session:panForCanvas()
	end

	--[=[
		@within UVCanvasUI

		Hides the canvas, ends any gesture in progress and frees the wireframe image.
	]=]
	function object:close()
		if not self.mode then
			return
		end

		endGesture()
		table.clear(self.touches)
		self.openMaid:doCleaning()

		self.stickerTool:setCanvasPlacement(nil, nil)
		destroyWireframe()

		self.mode = nil
		self.anchorPanel = nil
		self.container.Visible = false
		self.view:setCursor(nil, 0)
		self.stickerHandle.moveHandle.Visible = false
	end

	--[=[
		@within UVCanvasUI
		@return boolean -- true while the canvas is showing
	]=]
	function object:isOpen(): boolean
		return self.mode ~= nil
	end

	--[=[
		@within UVCanvasUI
		@param meshPart MeshPart -- any part of the layer stack to show
	]=]
	function object:selectLayerStack(meshPart: MeshPart)
		endGesture()

		self.selectedMeshPart = meshPart
		self.view:setImages({ getOutputImage(meshPart) }, getCellSize())

		destroyWireframe()
		if self.isWireframeVisible then
			rebuildWireframe()
		end

		updateStickerPlacement()
	end

	--[=[
		@within UVCanvasUI
		@param isVisible boolean -- whether the UV wireframe overlay shows; built on first show
	]=]
	function object:setWireframeVisible(isVisible: boolean)
		self.isWireframeVisible = isVisible
		self.view:setWireframeVisible(isVisible)

		if isVisible and self:isOpen() then
			rebuildWireframe()
		end
	end

	--[=[
		@within UVCanvasUI
		@param texel Vector2 -- a texel on the selected layer stack
		@return MeshPart? -- the part whose region owns the texel, or nil when none does

		Parts sharing one layer stack each stencil to their own region, so a stroke has to target
		the part that owns the texel under the pointer.
	]=]
	function object:resolvePaintTarget(texel: Vector2): MeshPart?
		local selectedMeshPart = self.selectedMeshPart
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

	function object:destroy()
		self:close()
		maid:doCleaning()
	end

	return object
end

return UVCanvasUI

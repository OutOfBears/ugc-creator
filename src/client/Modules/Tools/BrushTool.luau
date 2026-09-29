local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local BrushTips = require(ReplicatedStorage.Shared.Data.BrushTips)
local Brushes = require(ReplicatedStorage.Shared.Modules.Brushes)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationInput = require("../CreationInput")
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local ImageEditActions = require(ReplicatedStorage.Shared.Modules.Actions.ImageEditActions)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MeshUtils = require(ReplicatedStorage.Shared.Modules.Utils.MeshUtils)
local Message = require("../Message")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)
local ToolInput = require("../ToolInput")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

export type BrushTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	inputManager: CreationInput.CreationInput,
	currentBrushSize: number,
	currentBrushColor: Color3,
	currentBrushTransparency: number,
	brushTipId: string,
	isReflectiveMode: boolean,
	currentEraserSize: number,
	touchPoints: { InputObject },
	currentState: number,
	currentBrush: any,
	useProjectionBrush: boolean,
	isLinearOverride: boolean,
	lastVirtualCursorUpdate: number,
	lastDrawnMeshPart: MeshPart?,
	activePaintLayerId: string,
	brushInputGui: ScreenGui,
	inputCapture: Frame,
	maid: Maid.Maid,
	-- methods
	setStatePainting: (self: BrushTool) -> (),
	setStateErasing: (self: BrushTool) -> (),
	onBrushSizeChanged: (self: BrushTool, newSize: number) -> (),
	onEraserSizeChanged: (self: BrushTool, newSize: number) -> (),
	getBrushSize: (self: BrushTool) -> number,
	getEraserSize: (self: BrushTool) -> number,
	getActiveSize: (self: BrushTool) -> number,
	onColorChanged: (self: BrushTool, newColor: Color3) -> (),
	setTransparency: (self: BrushTool, colorPickerOpacity: number) -> (),
	setIsReflective: (self: BrushTool, isReflectiveMode: boolean) -> (),
	setActivePaintLayer: (self: BrushTool, layerId: string) -> (),
	enable: (self: BrushTool) -> (),
	disable: (self: BrushTool) -> (),
	clearAll: (self: BrushTool) -> (),
	createNewBrush: (self: BrushTool, meshPart: MeshPart, forceLinearBrush: boolean?) -> (),
	beginStroke: (self: BrushTool, meshPart: MeshPart, drawInfo: Brushes.DrawInfo, forceLinearBrush: boolean?) -> (),
	continueStroke: (self: BrushTool, meshPart: MeshPart, drawInfo: Brushes.DrawInfo) -> (),
	endStroke: (self: BrushTool) -> (),
	castRayFromCamera: (self: BrushTool, inputPosition: Vector2) -> (boolean, MeshUtils.EditableMeshRaycastResult?),
	setupMeshDraw: (self: BrushTool) -> (),
	handleInputChanged: (self: BrushTool, inputPosition: Vector2, isVirtualCursorMovement: boolean) -> (),
	destroy: (self: BrushTool) -> (),
}

--[=[
	@class BrushTool
	@client

	Paints freeform brush strokes onto the active paint layer's EditableImages. Each layer has one
	image per layer stack, so a stroke that crosses onto a part with a different stack restarts as
	a fresh brush.
]=]
local function BrushTool(modelInfo: ModelInfo.ModelInfo, inputManager: CreationInput.CreationInput): BrushTool
	local maid = Maid.new()
	local object = {} :: BrushTool

	object.modelInfo = modelInfo
	object.inputManager = inputManager

	object.currentBrushSize = 10
	object.currentBrushColor = Color3.new(1, 1, 1)
	object.currentBrushTransparency = 0
	object.brushTipId = BrushTips.defaultTipId
	object.isReflectiveMode = false
	object.currentEraserSize = 5

	object.touchPoints = {}

	object.currentState = CreationConfig.paintStates.painting
	object.currentBrush = nil

	object.useProjectionBrush = CreationConfig.projectionEnabled
	object.isLinearOverride = false

	object.lastVirtualCursorUpdate = 0
	object.activePaintLayerId = CreationConfig.defaultPaintLayerId
	object.maid = maid

	--[=[
		@within BrushTool

		Switches the brush back to painting; the painting and erasing sizes are tracked apart.
	]=]
	function object:setStatePainting()
		self.currentState = CreationConfig.paintStates.painting
	end

	--[=[
		@within BrushTool
	]=]
	function object:setStateErasing()
		self.currentState = CreationConfig.paintStates.erasing
	end

	--[=[
		@within BrushTool
		@param newSize number -- the new radius, applied to whichever state is active
	]=]
	function object:onBrushSizeChanged(newSize: number)
		if self.currentState == CreationConfig.paintStates.painting then
			self.currentBrushSize = newSize
		elseif self.currentState == CreationConfig.paintStates.erasing then
			self.currentEraserSize = newSize
		end
	end

	--[=[
		@within BrushTool
		@param newSize number -- the new eraser radius
	]=]
	function object:onEraserSizeChanged(newSize: number)
		self.currentEraserSize = newSize
	end

	--[=[
		@within BrushTool
		@return number -- the paint brush radius
	]=]
	function object:getBrushSize(): number
		return self.currentBrushSize
	end

	--[=[
		@within BrushTool
		@return number -- the eraser radius
	]=]
	function object:getEraserSize(): number
		return self.currentEraserSize
	end

	--[=[
		@within BrushTool
		@return number -- the radius of whichever of paint/erase is currently active
	]=]
	function object:getActiveSize(): number
		if self.currentState == CreationConfig.paintStates.erasing then
			return self.currentEraserSize
		end

		return self.currentBrushSize
	end

	--[=[
		@within BrushTool
		@param newColor Color3 -- the color subsequent strokes paint with
	]=]
	function object:onColorChanged(newColor: Color3)
		self.currentBrushColor = newColor
	end

	--[=[
		@within BrushTool
		@param colorPickerOpacity number -- opacity from the color picker, where 1 is solid
	]=]
	function object:setTransparency(colorPickerOpacity: number)
		self.currentBrushTransparency = 1 - colorPickerOpacity
	end

	--[=[
		@within BrushTool
		@param isReflectiveMode boolean -- whether strokes also write the reflective PBR maps
	]=]
	function object:setIsReflective(isReflectiveMode: boolean)
		self.isReflectiveMode = isReflectiveMode
	end

	--[=[
		@within BrushTool
		@param layerId string -- the paint layer later strokes, and clearAll, act on

		Ends any stroke in progress so it can't carry over onto the new layer.
	]=]
	function object:setActivePaintLayer(layerId: string)
		self:endStroke()
		self.activePaintLayerId = layerId
	end

	--[=[
		@within BrushTool

		Starts capturing input. The tool is constructed disabled so it only takes input once the
		player has actually picked the brush.
	]=]
	function object:enable()
		self.brushInputGui.Enabled = true
	end

	--[=[
		@within BrushTool
	]=]
	function object:disable()
		self.brushInputGui.Enabled = false
	end

	--[=[
		@within BrushTool

		Wipes the active paint layer on every MeshPart.
	]=]
	function object:clearAll()
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		for _, meshPart in self.modelInfo:getMeshParts() do
			if textureInfo:getPaintLayerImage(meshPart, self.activePaintLayerId) then
				local clearBrushActionMetadata: ImageEditActions.ClearBrushActionMetadata = {
					targetMeshPartName = meshPart.Name,
					paintLayerId = self.activePaintLayerId,
				}

				local action = Actions.createAction(Actions.ActionTypes.ClearBrush, clearBrushActionMetadata)

				Actions.executeAction(self.modelInfo, action)
				Network.fire("SubmitAction", action)

				textureInfo:updateOutputColorMap(meshPart)
			end
		end
	end

	--[=[
		@within BrushTool
		@param meshPart MeshPart -- the part the next stroke starts on
		@param forceLinearBrush boolean? -- paint in texture space even when projection is enabled

		Builds the brush for a stroke, wired to commit each finished segment both locally and to
		the server.
	]=]
	function object:createNewBrush(meshPart: MeshPart, forceLinearBrush: boolean?)
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
		local paintLayerId = self.activePaintLayerId
		local brushLayer = textureInfo:getPaintLayerImage(meshPart, paintLayerId)
		local pbrMaps = {
			roughnessMap = textureInfo:getRoughnessMap(meshPart),
			metalnessMap = textureInfo:getMetalnessMap(meshPart),
			normalMap = textureInfo:getNormalMap(meshPart),
		}

		if self.currentBrush then
			self.currentBrush:destroy()
		end

		self.currentBrush = nil
		self.isLinearOverride = forceLinearBrush == true

		local useProjectionBrush = self.useProjectionBrush and not self.isLinearOverride

		if useProjectionBrush then
			self.currentBrush = Brushes.ProjectionBrush(brushLayer, textureInfo, pbrMaps)
			self.currentBrush:setCommitBrushStrokeCallback(
				function(projectionBrushActionMetadata: ImageEditActions.ProjectionBrushActionMetadata)
					projectionBrushActionMetadata.paintLayerId = paintLayerId
					local brushAction =
						Actions.createAction(Actions.ActionTypes.ProjectionBrush, projectionBrushActionMetadata)

					if self.currentBrush:getRequireLocalExecute() then
						Actions.executeAction(self.modelInfo, brushAction)

						local latestTextureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
						latestTextureInfo:updateOutputColorMap(self.lastDrawnMeshPart)
					end

					Network.fire("SubmitAction", brushAction)
				end
			)
		else
			self.currentBrush = Brushes.LinearBrush(brushLayer, textureInfo)
			self.currentBrush:setCommitBrushStrokeCallback(
				function(linearBrushActionMetadata: ImageEditActions.LinearBrushActionMetadata)
					linearBrushActionMetadata.paintLayerId = paintLayerId
					local brushAction = Actions.createAction(Actions.ActionTypes.LinearBrush, linearBrushActionMetadata)

					if self.currentBrush:getRequireLocalExecute() then
						Actions.executeAction(self.modelInfo, brushAction)

						local latestTextureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
						latestTextureInfo:updateOutputColorMap(self.lastDrawnMeshPart)
					end

					Network.fire("SubmitAction", brushAction)
				end
			)
		end

		local currentColor = self.currentState == CreationConfig.paintStates.erasing and Color3.new(0, 0, 0)
			or self.currentBrushColor
		local currentTransparency = self.currentState == CreationConfig.paintStates.erasing and 1.0 or 0.0
		if useProjectionBrush then
			-- TODO CLI-202002: implement non-opaque transparency support for linear brush
			currentTransparency = self.currentBrushTransparency
		end
		local currentColorBlendType = self.currentState == CreationConfig.paintStates.erasing
				and Enum.ImageCombineType.Multiply
			or Enum.ImageCombineType.BlendSourceOver
		local currentAlphaBlendType = self.currentState == CreationConfig.paintStates.erasing
				and Enum.ImageAlphaType.LockCanvasColor
			or Enum.ImageAlphaType.Default

		self.currentBrush:setColor(currentColor)
		self.currentBrush:setIsReflective(self.isReflectiveMode)
		self.currentBrush:setSize(self:getActiveSize())
		self.currentBrush:setTransparency(currentTransparency)
		self.currentBrush:setTip(self.brushTipId)
		self.currentBrush:setCurrentMeshPart(meshPart)
		self.currentBrush:setColorBlendType(currentColorBlendType)
		self.currentBrush:setAlphaBlendType(currentAlphaBlendType)
		self.currentBrush:setAllMeshPart(self.modelInfo:getMeshInfo():getEditableMeshMap())
		self.currentBrush:setState(self.currentState)
	end

	--[=[
		@within BrushTool
		@param inputPosition Vector2 -- screen position to cast through
		@return boolean -- whether the model was hit
		@return EditableMeshRaycastResult? -- the closest hit along the ray
	]=]
	function object:castRayFromCamera(inputPosition: Vector2): (boolean, MeshUtils.EditableMeshRaycastResult?)
		local camera = workspace.CurrentCamera
		if not camera then
			return false, nil
		end

		local ray = camera:ScreenPointToRay(inputPosition.X, inputPosition.Y)

		local meshInfo = self.modelInfo:getMeshInfo()
		local closestRaycastResult: MeshUtils.EditableMeshRaycastResult? =
			MeshUtils.raycastAll(ray, meshInfo:getEditableMeshMap(), meshInfo:getScaleFactorMap())

		if closestRaycastResult ~= nil and closestRaycastResult.triangleId then
			return true, closestRaycastResult
		end
		return false, nil
	end

	--[=[
		@within BrushTool

		Builds the full-screen input capture and wires the pen down/move/up handlers. Input only
		reaches the tool while its gui is enabled.
	]=]
	function object:setupMeshDraw()
		local inputCapture = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}) :: Frame

		local brushInputGui = Create("ScreenGui", {
			Name = "BrushInputGui",
			Children = { inputCapture },
			Parent = PlayerGui,
		}) :: ScreenGui

		self.brushInputGui = maid:add(brushInputGui)
		self.inputCapture = inputCapture

		local penDown = false

		-- A drag can fire several move events per frame; only the latest is drawn, once per frame.
		local pendingInputPosition: Vector2? = nil
		local pendingIsVirtualCursorMovement = false
		local function applyPendingInput()
			maid.pendingInput = nil

			local inputPosition = pendingInputPosition
			pendingInputPosition = nil
			if inputPosition then
				self:handleInputChanged(inputPosition, pendingIsVirtualCursorMovement)
			end
		end

		maid:add(inputCapture.InputBegan:Connect(function(input, gameProcessedEvent)
			if gameProcessedEvent then
				return
			end

			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			local didHitModel, raycastResult: MeshUtils.EditableMeshRaycastResult? =
				self:castRayFromCamera(ToolInput.getInputPosition(input))
			if didHitModel == false or not raycastResult then
				return
			end

			-- Multiple simultaneous brush strokes are not supported.
			if #self.touchPoints > 0 then
				return
			end

			self.touchPoints[#self.touchPoints + 1] = input

			if self.inputManager:tryGrabLock(self) == false then
				return
			end

			penDown = true

			local editableMeshMap = self.modelInfo:getMeshInfo():getEditableMeshMap()
			local hitEditableMesh = editableMeshMap[raycastResult.meshPart]

			local textureCoord = MeshUtils.getTextureCoordinate(
				hitEditableMesh,
				raycastResult.triangleId,
				raycastResult.barycentricCoordinate
			)

			local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
			local textureSize = textureInfo:getImageSize(raycastResult.meshPart)

			local drawX = textureCoord.X * textureSize.X
			local drawY = textureCoord.Y * textureSize.Y

			local drawPosition = Vector2.new(math.floor(drawX), math.floor(drawY))

			local drawInfo: Brushes.DrawInfo = {
				textureDrawPosition = drawPosition,
				cameraCFrame = workspace.CurrentCamera.CFrame,
				castedPoint = raycastResult.meshPart.CFrame:PointToWorldSpace(raycastResult.point),
				isVirtualCursorMovement = false,
			}
			self:beginStroke(raycastResult.meshPart, drawInfo)
		end))

		maid:add(UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
			if not penDown then
				return
			end

			local isVirtualCursorMovement = ToolInput.isVirtualCursor(input.UserInputType)
				and input.KeyCode == Enum.KeyCode.Thumbstick1

			if not isVirtualCursorMovement then
				if gameProcessedEvent then
					return
				end

				if
					input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
			end

			if input.UserInputState == Enum.UserInputType.Touch then
				local isValidTouchInput = false
				for _, touchInput in pairs(self.touchPoints) do
					if input == touchInput then
						isValidTouchInput = true
						break
					end
				end

				if isValidTouchInput ~= true then
					self.currentBrush:penUp()
					return
				end
			end

			local inputPosition = ToolInput.getInputPosition(input)
			if isVirtualCursorMovement then
				local ticks = tick()
				if ticks - self.lastVirtualCursorUpdate < (1 / CreationConfig.input.virtualCursorUpdatesPerSecond) then
					return
				end
				self.lastVirtualCursorUpdate = ticks
			end

			pendingInputPosition = inputPosition
			pendingIsVirtualCursorMovement = isVirtualCursorMovement
			if not maid.pendingInput then
				maid.pendingInput = RunService.PreRender:Once(applyPendingInput)
			end
		end))

		maid:add(UserInputService.InputEnded:Connect(function(input, _gameProcessedEvent)
			local usingVirtualCursor = ToolInput.isVirtualCursor(input.UserInputType)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
				and (not usingVirtualCursor or input.KeyCode ~= Enum.KeyCode.ButtonA)
			then
				return
			end

			local wasPenDown = penDown
			penDown = false

			if usingVirtualCursor then
				self.touchPoints = {}
			else
				for i, touchInput in pairs(self.touchPoints) do
					if touchInput == input then
						table.remove(self.touchPoints, i)
						break
					end
				end
			end

			if wasPenDown then
				applyPendingInput()
				self:endStroke()
			end
		end))
	end

	--[=[
		@within BrushTool
		@param meshPart MeshPart -- the part whose layer the stroke paints
		@param drawInfo Brushes.DrawInfo -- where the stroke starts
		@param forceLinearBrush boolean? -- paint in texture space, as the 2D canvas does

		Starts a stroke at a texture position, reusing the current brush when it already targets
		the same layer.
	]=]
	function object:beginStroke(meshPart: MeshPart, drawInfo: Brushes.DrawInfo, forceLinearBrush: boolean?)
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local activeLayer = textureInfo:getPaintLayer(self.activePaintLayerId)
		if not activeLayer or not activeLayer.visible then
			task.spawn(Message.create, CreationStrings.layerHiddenPaint)
			return
		end

		if
			not self.currentBrush
			or self.isLinearOverride ~= (forceLinearBrush == true)
			or (
				self.lastDrawnMeshPart ~= meshPart
				and not textureInfo:meshPartsShareLayer(self.lastDrawnMeshPart, meshPart)
			)
		then
			self:createNewBrush(meshPart, forceLinearBrush)
		end

		self.lastDrawnMeshPart = meshPart

		self.currentBrush:penDown(drawInfo)

		textureInfo:updateOutputColorMap(meshPart)
	end

	--[=[
		@within BrushTool
		@param meshPart MeshPart -- the part under the pen now
		@param drawInfo Brushes.DrawInfo -- where the pen moved to

		Extends the active stroke, restarting the brush when the pen crosses onto another part that
		shares the same layer so its region stencil stays correct.
	]=]
	function object:continueStroke(meshPart: MeshPart, drawInfo: Brushes.DrawInfo)
		if not self.currentBrush then
			return
		end

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		if self.lastDrawnMeshPart ~= meshPart and textureInfo:meshPartsShareLayer(self.lastDrawnMeshPart, meshPart) then
			self.currentBrush:penUp()
			self:createNewBrush(meshPart, self.isLinearOverride)

			self.currentBrush:penDown(drawInfo)
		else
			self.currentBrush:movePen(drawInfo)
		end

		self.lastDrawnMeshPart = meshPart

		textureInfo:updateOutputColorMap(meshPart)
	end

	--[=[
		@within BrushTool

		Commits and tears down the active stroke. Safe to call when no stroke is active.
	]=]
	function object:endStroke()
		if not self.currentBrush then
			return
		end

		self.currentBrush:penUp()
		self.currentBrush:destroy()
		self.currentBrush = nil
	end

	--[=[
		@within BrushTool
		@param inputPosition Vector2 -- screen position the pen moved to
		@param isVirtualCursorMovement boolean -- true when driven by a gamepad virtual cursor

		Continues the stroke at a new screen position, restarting the brush when the pen crosses
		onto a MeshPart that shares no layer with the last one.
	]=]
	function object:handleInputChanged(inputPosition: Vector2, isVirtualCursorMovement: boolean)
		if not self.currentBrush then
			return
		end

		local didHitModel, raycastResult: MeshUtils.EditableMeshRaycastResult? = self:castRayFromCamera(inputPosition)
		if not didHitModel or not raycastResult then
			self.currentBrush:penUp()
			return
		end

		local textureCoord = MeshUtils.getTextureCoordinate(
			raycastResult.editableMesh,
			raycastResult.triangleId,
			raycastResult.barycentricCoordinate
		)

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
		local drawPosition = textureCoord * textureInfo:getImageSize(raycastResult.meshPart)

		local drawInfo: Brushes.DrawInfo = {
			textureDrawPosition = drawPosition,
			cameraCFrame = workspace.CurrentCamera.CFrame,
			castedPoint = raycastResult.meshPart.CFrame:PointToWorldSpace(raycastResult.point),
			isVirtualCursorMovement = isVirtualCursorMovement,
		}

		self:continueStroke(raycastResult.meshPart, drawInfo)
	end

	function object:destroy()
		if self.currentBrush then
			self.currentBrush:destroy()
		end

		maid:doCleaning()
	end

	object:setupMeshDraw()

	object:disable()

	return object
end

return BrushTool

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationInput = require("../CreationInput")
local GeometryUtil = require(ReplicatedStorage.Shared.Modules.Utils.GeometryUtil)
local ImageEditActions = require(ReplicatedStorage.Shared.Modules.Actions.ImageEditActions)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MeshInfo = require(ReplicatedStorage.Shared.Modules.MeshInfo)
local MeshUtils = require(ReplicatedStorage.Shared.Modules.Utils.MeshUtils)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)
local ToolInput = require("../ToolInput")
local Types = require(ReplicatedStorage.Shared.Types)

export type StickerData = {
	textureId: string,

	projectionDirection: Vector3,

	texturePosition: Vector2,
	rotation: number,
	scale: number,

	isTiled: boolean,
	tilePadding: number?,

	targetMeshPart: MeshPart,

	positionMarker: Part?,
	positionMarkerOffset: CFrame?,

	stickerLayerNumber: number,
	paintLayerId: string,

	isTextureSpace: boolean?,
}

export type StickersState = {
	textureIds: { string },
	selectedIndex: number,
	count: number,
}

export type StickerTool = {
	-- vars
	state: Charm.Atom<StickersState>,
	modelInfo: ModelInfo.ModelInfo,
	isAccessory: boolean,
	inputManager: CreationInput.CreationInput,
	currentlySelectedSticker: number,
	isDragging: boolean,
	isRotating: boolean,
	isScaling: boolean,
	lastStickerAction: Actions.Action?,
	selectedRegionName: string?,
	useProjectionSticker: boolean,
	appliedStickers: { StickerData },
	stickerCounter: number,
	canvasPlacementMeshPart: MeshPart?,
	canvasPlacementPosition: Vector2?,
	activePaintLayerId: string,
	mouseDownPos: Vector2?,
	handle: Charm.Atom<Types.EditHandleState>,
	maid: Maid.Maid,
	-- methods
	selectSticker: (self: StickerTool, index: number) -> (),
	refreshMarkerPosition: (self: StickerTool, stickerData: StickerData?) -> (),
	moveStickerBetweenParts: (self: StickerTool, stickerData: StickerData, newTargetMeshPart: MeshPart) -> (),
	beginHandleGesture: (self: StickerTool, kind: string, input: InputObject) -> (),
	dragSticker: (self: StickerTool, input: InputObject) -> (),
	rotateSticker: (self: StickerTool, input: InputObject) -> (),
	scaleSticker: (self: StickerTool, input: InputObject) -> (),
	refreshHandleUI: (self: StickerTool) -> (),
	allocateLayer: (self: StickerTool) -> number?,
	applySticker: (self: StickerTool, imageAssetId: string) -> (),
	placeSticker: (self: StickerTool, stickerData: StickerData) -> (),
	redrawSticker: (self: StickerTool, stickerData: StickerData, shouldFireServer: boolean) -> (),
	onPatternPaddingChanged: (self: StickerTool, newPadding: number, isFinalInput: boolean) -> (),
	deleteCurrentSticker: (self: StickerTool) -> (),
	setPatterned: (self: StickerTool, isPatterned: boolean) -> (),
	setSelectedRegion: (self: StickerTool, regionName: string) -> (),
	safelyRedrawSticker: (self: StickerTool) -> (),
	isPatterned: (self: StickerTool) -> boolean,
	hasAppliedStickers: (self: StickerTool) -> boolean,
	setCanvasPlacement: (self: StickerTool, meshPart: MeshPart?, texturePosition: Vector2?) -> (),
	setActivePaintLayer: (self: StickerTool, layerId: string) -> (),
	forgetStickersOnLayer: (self: StickerTool, layerId: string) -> (),
	getSelectedSticker: (self: StickerTool) -> StickerData?,
	moveSelectedStickerTo: (self: StickerTool, meshPart: MeshPart, texturePosition: Vector2) -> (),
	setSelectedStickerTransform: (self: StickerTool, rotation: number?, scale: number?) -> (),
	commitStickerEdit: (self: StickerTool) -> (),
	enable: (self: StickerTool) -> (),
	disable: (self: StickerTool) -> (),
	destroy: (self: StickerTool) -> (),
}

local function getRayPlaneIntersection(rayStart, rayDirection, planePoint, planeNormal)
	local denom = planeNormal:Dot(rayDirection)
	if math.abs(denom) > 0.0001 then
		local t = (planePoint - rayStart):Dot(planeNormal) / denom
		if t >= 0 then
			return true, rayStart + rayDirection * t
		end
	end
	return false, 0
end

local function rotateVectorAroundAxis(v, angleDegrees, axis)
	local angleRadians = math.rad(angleDegrees)
	return CFrame.fromAxisAngle(axis, angleRadians):VectorToWorldSpace(v)
end

local function getAverageMeshPartPosition(meshParts: { MeshPart }): Vector3
	local averageMeshPartPosition = Vector3.zero
	local numMeshes = 0
	for _, meshPart in meshParts do
		averageMeshPartPosition = averageMeshPartPosition + meshPart.Position
		numMeshes = numMeshes + 1
	end
	averageMeshPartPosition = averageMeshPartPosition / numMeshes

	return averageMeshPartPosition
end

local function getClosestMeshPart(modelInfo: ModelInfo.ModelInfo): (MeshPart, EditableMesh, number)
	local closestVertex = nil
	local editableMesh: EditableMesh = nil
	local meshPart = nil

	local meshInfo: MeshInfo.MeshInfo = modelInfo:getMeshInfo()

	local averageMeshPartPosition = getAverageMeshPartPosition(modelInfo:getMeshParts())

	local rayOrigin = workspace.CurrentCamera.CFrame.Position
	local rayTarget = averageMeshPartPosition + Vector3.FromAxis(Enum.Axis.Y)
	local rayDirection = rayTarget - rayOrigin
	local raycastResult: MeshUtils.EditableMeshRaycastResult? = MeshUtils.raycastAll(
		Ray.new(rayOrigin, rayDirection),
		meshInfo:getEditableMeshMap(),
		meshInfo:getScaleFactorMap()
	)
	if raycastResult == nil then
		-- Concave meshes can swallow the ray, so fall back to the vertex nearest the camera.
		for mappedMeshPart, mappedEditableMesh in pairs(meshInfo:getEditableMeshMap()) do
			editableMesh = mappedEditableMesh
			meshPart = mappedMeshPart
			closestVertex = mappedEditableMesh:FindClosestVertex(workspace.CurrentCamera.CFrame.Position)
		end
	else
		editableMesh = raycastResult.editableMesh
		meshPart = raycastResult.meshPart
		closestVertex = editableMesh:FindClosestVertex(raycastResult.point)
	end

	return meshPart, editableMesh, closestVertex
end

local function createPositionMarker(newCFrame: CFrame): Part
	local directionMarker = Create("Part", {
		Name = "StickerDirectionMarker",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = newCFrame,
		Transparency = 1,
		Color = Color3.new(1, 0, 0),
	}) :: Part

	return Create("Part", {
		Name = "StickerPositionMarker",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = newCFrame,
		Transparency = 1,
		Color = Color3.new(0, 1, 0),
		Children = { directionMarker },
		Parent = workspace,
	}) :: Part
end

--[=[
	@class StickerTool
	@client

	Adds stickers to a creation and moves, rotates, scales and tiles them. Each sticker owns its
	own texture layer and belongs to the paint layer that was active when it was placed. Dragging casts a ray from the camera to the cursor, converts the hit point
	into UV coordinates, and redraws the sticker at those coordinates on the 2D texture.

	`state` is a snapshot of the applied stickers and the selection, republished after each change,
	and `handle` places the on-screen edit handle; the UI renders both and forwards presses on the
	handle to `beginHandleGesture`.
]=]
local function StickerTool(modelInfo: ModelInfo.ModelInfo, inputManager: CreationInput.CreationInput): StickerTool
	local maid = Maid.new()
	local object = {} :: StickerTool

	object.modelInfo = modelInfo
	object.isAccessory = modelInfo:getCreationType() == CreationConfig.creationTypes.accessory
	object.inputManager = inputManager

	object.currentlySelectedSticker = 0

	object.isDragging = false
	object.isRotating = false
	object.isScaling = false
	object.lastStickerAction = nil

	object.selectedRegionName = nil

	object.useProjectionSticker = CreationConfig.projectionEnabled

	object.appliedStickers = modelInfo:getAppliedStickers() :: { StickerData }
	object.stickerCounter = #object.appliedStickers
	object.activePaintLayerId = CreationConfig.defaultPaintLayerId

	object.maid = maid

	local function publish()
		local textureIds = {}
		for index, stickerData in object.appliedStickers do
			textureIds[index] = stickerData.textureId
		end

		object.state({
			textureIds = textureIds,
			selectedIndex = object.currentlySelectedSticker,
			count = object.stickerCounter,
		})
	end
	object.state = Charm.atom(nil :: any)
	publish()

	object.handle = Charm.atom({ visible = false, offset = Vector2.zero, scale = 1, rotation = 0 })

	local function setHandleVisible(visible: boolean)
		local current = object.handle()
		if current.visible ~= visible then
			object.handle({
				visible = visible,
				offset = current.offset,
				scale = current.scale,
				rotation = current.rotation,
			})
		end
	end

	--[=[
		@within StickerTool
		@param index number -- position of the sticker in the applied list

		Selects a sticker and warms the cache of its texture so a redraw is ready to go.
	]=]
	function object:selectSticker(index: number)
		self.currentlySelectedSticker = index

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
		local textureId = self.appliedStickers[index].textureId
		textureInfo:getOrCreateEditableImageByTextureId(textureId)

		self:refreshHandleUI()
		publish()
	end

	--[=[
		@within StickerTool
		@param stickerData StickerData? -- the sticker whose marker moved with the model
	]=]
	function object:refreshMarkerPosition(stickerData: StickerData?)
		if not stickerData then
			return
		end

		local marker = stickerData.positionMarker
		local markerOffset = stickerData.positionMarkerOffset
		if marker and markerOffset then
			marker.CFrame = stickerData.targetMeshPart.CFrame:ToWorldSpace(markerOffset)

			local directionIndicator = marker:FindFirstChild("StickerDirectionMarker")
			if directionIndicator then
				directionIndicator.Position = marker.Position + stickerData.projectionDirection
			end
		end

		self:refreshHandleUI()
	end

	--[=[
		@within StickerTool
		@param stickerData StickerData -- the sticker being dragged
		@param newTargetMeshPart MeshPart -- the part it moved onto

		Retargets a sticker, clearing it off the old part when the two don't share a layer.
	]=]
	function object:moveStickerBetweenParts(stickerData: StickerData, newTargetMeshPart: MeshPart)
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local oldMeshPart = stickerData.targetMeshPart
		stickerData.targetMeshPart = newTargetMeshPart

		if textureInfo:meshPartsShareLayer(oldMeshPart, newTargetMeshPart) then
			return
		end

		local removeStickerActionMetadata: ImageEditActions.RemoveStickerActionMetadata = {
			targetMeshPartName = oldMeshPart.Name,
			stickerLayerNumber = stickerData.stickerLayerNumber,
		}

		local removeStickerAction = Actions.createAction(Actions.ActionTypes.RemoveSticker, removeStickerActionMetadata)
		Actions.executeAction(self.modelInfo, removeStickerAction)

		textureInfo:updateOutputColorMap(oldMeshPart)

		Network.fire("SubmitAction", removeStickerAction)
	end

	--[=[
		@within StickerTool
		@param kind string -- which part of the handle was pressed: `"move"`, `"rotate"` or `"scale"`
		@param input InputObject -- the press

		Starts a drag, rotate or scale gesture from the sticker handle. The action built while
		dragging is only mirrored to the server once the gesture ends.
	]=]
	function object:beginHandleGesture(kind: string, input: InputObject)
		if not ToolInput.isValidSelectingInput(input) then
			return
		end

		if kind == "move" then
			if self.isRotating or self.isScaling or not self.inputManager:tryGrabLock(self) then
				return
			end

			self.isDragging = true
		elseif kind == "rotate" then
			if self.isDragging or self.isScaling or not self.inputManager:tryGrabLock(self) then
				return
			end

			self.isRotating = true
		elseif kind == "scale" then
			if self.isRotating or self.isDragging or not self.inputManager:tryGrabLock(self) then
				return
			end

			self.isScaling = true
			self.mouseDownPos = ToolInput.getInputPosition(input)
		end
	end

	--[=[
		@within StickerTool
		@param input InputObject -- the drag input

		Moves the selected sticker to the UV coordinate under the cursor.
	]=]
	function object:dragSticker(input: InputObject)
		local inputPosition = ToolInput.getInputPosition(input)
		local camera = workspace.CurrentCamera
		local ray = camera:ScreenPointToRay(inputPosition.X, inputPosition.Y, 1)

		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if not selectedSticker then
			return
		end

		local marker = selectedSticker.positionMarker
		if not marker then
			return
		end

		local meshPart = selectedSticker.targetMeshPart

		local meshInfo: MeshInfo.MeshInfo = self.modelInfo:getMeshInfo()

		local raycastResult: MeshUtils.EditableMeshRaycastResult? =
			MeshUtils.raycastAll(ray, meshInfo:getEditableMeshMap(), meshInfo:getScaleFactorMap())
		if raycastResult == nil then
			-- The cursor can leave the model mid-drag.
			return
		end

		if raycastResult.meshPart ~= meshPart then
			self:moveStickerBetweenParts(selectedSticker, raycastResult.meshPart)
		end

		marker.CFrame = MeshUtils.editableMeshRaycastToCFrame(
			raycastResult.editableMesh,
			raycastResult.meshPart,
			raycastResult.point,
			raycastResult.triangleId,
			raycastResult.scaleFactor
		)
		selectedSticker.positionMarkerOffset = meshPart.CFrame:ToObjectSpace(marker.CFrame)

		local directionIndicator = marker:FindFirstChild("StickerDirectionMarker")
		if directionIndicator then
			directionIndicator.Position = marker.Position + selectedSticker.projectionDirection
		end

		local uvCoord = MeshUtils.getTextureCoordinate(
			raycastResult.editableMesh,
			raycastResult.triangleId,
			raycastResult.barycentricCoordinate
		)
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local textureCoord = uvCoord * textureInfo:getImageSize(meshPart)
		selectedSticker.texturePosition = textureCoord
		self:refreshHandleUI()
		self:redrawSticker(selectedSticker, false)
	end

	--[=[
		@within StickerTool
		@param input InputObject -- the drag input

		Spins the selected sticker to follow the cursor projected onto the sticker's plane.
	]=]
	function object:rotateSticker(input: InputObject)
		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if not selectedSticker then
			return
		end

		local marker = selectedSticker.positionMarker
		if not marker then
			return
		end

		local camera = workspace.CurrentCamera
		local rayOrigin = camera.CFrame.Position
		local inputPosition = ToolInput.getInputPosition(input)
		local ray = camera:ScreenPointToRay(inputPosition.X, inputPosition.Y, 1)
		local planePoint = marker.Position
		local planeNormal = marker.CFrame.LookVector
		planeNormal = planeNormal.Unit
		local isIntersecting, intersection = getRayPlaneIntersection(rayOrigin, ray.Direction, planePoint, planeNormal)

		if not isIntersecting then
			warn("Sticker ray is not intersecting with plane for rotation.")
			return
		end

		local vectorDiff = intersection - planePoint
		vectorDiff = vectorDiff.Unit
		local upVector = rotateVectorAroundAxis(marker.CFrame.UpVector, selectedSticker.rotation, planeNormal)
		local upDot = upVector:Dot(vectorDiff)
		local cross = upVector:Cross(vectorDiff)

		local angle = math.atan2(cross:Dot(planeNormal), upDot)

		angle = math.deg(angle) + (90 - StyleTokens.style.RotateHandlePosDegrees)
		selectedSticker.rotation = math.abs((selectedSticker.rotation + angle) % 360) * -1

		self:refreshHandleUI()
		self:redrawSticker(selectedSticker, false)
	end

	--[=[
		@within StickerTool
		@param input InputObject -- the drag input

		Scales the selected sticker by horizontal drag distance, inverted while the scale handle
		has swung round to the left of the sticker.
	]=]
	function object:scaleSticker(input: InputObject)
		local LEFT_POSITION_MIN_ANGLE = -315
		local LEFT_POSITION_MAX_ANGLE = -135

		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if not selectedSticker then
			return
		end

		local inputPosition = ToolInput.getInputPosition(input)
		if not self.mouseDownPos then
			self.mouseDownPos = inputPosition
			return
		end

		local mouseMovement = inputPosition - self.mouseDownPos
		local scaleChange = mouseMovement.X * CreationConfig.scaleDragSensitivity
		if
			selectedSticker.rotation < LEFT_POSITION_MAX_ANGLE
			and selectedSticker.rotation >= LEFT_POSITION_MIN_ANGLE
		then
			scaleChange *= -1
		end
		selectedSticker.scale = math.max(selectedSticker.scale + scaleChange, 0.1)
		self.mouseDownPos = inputPosition

		self:refreshHandleUI()
		self:redrawSticker(selectedSticker, false)
	end

	--[=[
		@within StickerTool

		Moves the handles onto the selected sticker's screen position, or hides them when nothing
		is selected.
	]=]
	function object:refreshHandleUI()
		if self.currentlySelectedSticker == 0 then
			setHandleVisible(false)
			return
		else
			setHandleVisible(true)
		end

		local selectedSticker: StickerData = self.appliedStickers[self.currentlySelectedSticker]
		local marker = selectedSticker.positionMarker
		if not marker then
			setHandleVisible(false)
			return
		end

		local stickerPos3d = marker.Position
		local camera = workspace.CurrentCamera

		local moveHandlePos = camera:WorldToScreenPoint(stickerPos3d)

		self.handle({
			visible = true,
			offset = Vector2.new(moveHandlePos.X, moveHandlePos.Y),
			scale = selectedSticker.scale,
			rotation = selectedSticker.rotation,
		})
	end

	--[=[
		@within StickerTool
		@return number? -- the lowest free layer number, or nil when every layer is taken

		The layer number identifies a sticker; it says nothing about draw order.
	]=]
	function object:allocateLayer(): number?
		local usedSlots = {}
		for _, stickerData in self.appliedStickers do
			if stickerData.stickerLayerNumber then
				usedSlots[stickerData.stickerLayerNumber] = true
			end
		end

		for i = 1, CreationConfig.maxStickerLayers do
			if not usedSlots[i] then
				return i
			end
		end

		return nil
	end

	--[=[
		@within StickerTool
		@param imageAssetId string -- the sticker texture

		Stamps a new sticker onto the surface point nearest the camera and selects it.
	]=]
	function object:applySticker(imageAssetId: string)
		if self.stickerCounter >= CreationConfig.maxStickerLayers then
			return
		end

		local layerNumber = self:allocateLayer()
		if not layerNumber then
			return
		end

		local canvasMeshPart = self.canvasPlacementMeshPart
		local canvasPosition = self.canvasPlacementPosition
		if canvasMeshPart and canvasPosition then
			self:placeSticker({
				textureId = imageAssetId,
				projectionDirection = Vector3.zero,

				texturePosition = canvasPosition,
				rotation = 0,
				scale = if self.isAccessory then CreationConfig.accessoryStickerScale else 1,

				isTiled = false,
				tilePadding = 0,

				targetMeshPart = canvasMeshPart,

				stickerLayerNumber = layerNumber,
				paintLayerId = self.activePaintLayerId,

				isTextureSpace = true,
			})
			return
		end

		local meshPart, editableMesh, closestVertex = getClosestMeshPart(self.modelInfo)

		local closestVertexPos = editableMesh:GetPosition(closestVertex)
		local vertexPositions = MeshUtils.getVertexPositions(editableMesh)
		local meshScaleFactor = MeshUtils.getScaleFactor(meshPart, vertexPositions).X

		local faceID, _pointOnMesh, baryCoord = editableMesh:FindClosestPointOnSurface(closestVertexPos)
		local vertexNormal = Vector3.zero

		local vertexNormals = editableMesh:GetFaceNormals(faceID)
		vertexNormal = (baryCoord.x * editableMesh:GetNormal(vertexNormals[1]))
			+ (baryCoord.y * editableMesh:GetNormal(vertexNormals[2]))
			+ (baryCoord.z * editableMesh:GetNormal(vertexNormals[3]))

		-- Correctly scaled in object space, but not necessarily correctly rotated.
		local objectSpaceVector = closestVertexPos / meshScaleFactor

		local offset = meshPart.CFrame:VectorToWorldSpace(objectSpaceVector)
		local worldSpaceNormal = meshPart.CFrame:VectorToWorldSpace(vertexNormal)
		local newCFrame = CFrame.new(meshPart.Position + offset, meshPart.Position + offset + worldSpaceNormal)

		local uvCoord = Vector2.zero
		local faceUVs = editableMesh:GetFaceUVs(faceID)
		uvCoord = (baryCoord.x * editableMesh:GetUV(faceUVs[1]))
			+ (baryCoord.y * editableMesh:GetUV(faceUVs[2]))
			+ (baryCoord.z * editableMesh:GetUV(faceUVs[3]))
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local marker = createPositionMarker(newCFrame)

		local stickerData: StickerData = {
			textureId = imageAssetId,
			projectionDirection = workspace.CurrentCamera.CFrame.LookVector,

			texturePosition = uvCoord * textureInfo:getImageSize(meshPart),
			rotation = 0,
			scale = if self.isAccessory then CreationConfig.accessoryStickerScale else 1,

			isTiled = false,
			tilePadding = 0,

			targetMeshPart = meshPart,

			positionMarker = marker,
			positionMarkerOffset = meshPart.CFrame:ToObjectSpace(marker.CFrame),

			stickerLayerNumber = layerNumber,
			paintLayerId = self.activePaintLayerId,
		}

		self:placeSticker(stickerData)
	end

	--[=[
		@within StickerTool
		@private
		@param stickerData StickerData -- a fully built sticker that has not been drawn yet

		Adds a new sticker to the applied list, draws it and selects it.
	]=]
	function object:placeSticker(stickerData: StickerData)
		self.stickerCounter = self.stickerCounter + 1

		self.appliedStickers[#self.appliedStickers + 1] = stickerData

		self:redrawSticker(stickerData, true)

		self.currentlySelectedSticker = #self.appliedStickers

		setHandleVisible(true)
		self:refreshHandleUI()
		publish()
	end

	--[=[
		@within StickerTool
		@param stickerData StickerData -- the sticker to draw
		@param shouldFireServer boolean -- mirror the action now, or hold it until the gesture ends

		Redraws a sticker as tiled, projected or flat. Rotation and scale are only recomputed
		when they changed — a plain move reuses the cached, already-transformed sticker.
	]=]
	function object:redrawSticker(stickerData: StickerData, shouldFireServer: boolean)
		if stickerData.isTiled then
			local tiledStickerActionMetadata: ImageEditActions.TiledStickerActionMetadata = {
				textureId = stickerData.textureId,
				targetMeshPartName = stickerData.targetMeshPart.Name,
				stickerLayerNumber = stickerData.stickerLayerNumber,
				paintLayerId = stickerData.paintLayerId,

				texturePosition = stickerData.texturePosition,

				rotation = stickerData.rotation,
				scale = stickerData.scale,

				tilePadding = stickerData.tilePadding,

				regionName = self.selectedRegionName,
			}

			local tiledStickerAction =
				Actions.createAction(Actions.ActionTypes.TiledSticker, tiledStickerActionMetadata)

			Actions.executeAction(self.modelInfo, tiledStickerAction)

			if shouldFireServer then
				Network.fire("SubmitAction", tiledStickerAction)
			else
				self.lastStickerAction = tiledStickerAction
			end

			local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
			textureInfo:updateOutputColorMap(stickerData.targetMeshPart)
		elseif self.useProjectionSticker and stickerData.positionMarker then
			local drawTextureSet = {}
			local projectorCFrame = stickerData.positionMarker.CFrame
			local projectorBrushSize = Vector3.new(0.5, 0.5, 0.5) * stickerData.scale

			local meshPartsToUpdate: { MeshPart } = {}

			for _, meshPart in self.modelInfo:getMeshParts() do
				local collisionTest = GeometryUtil.testObbCollision(meshPart, projectorCFrame, projectorBrushSize)
				if collisionTest == true then
					local partTextureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

					local originalTextureId: string = partTextureInfo:getOriginalTextureId(meshPart)
					local firstDraw = drawTextureSet[originalTextureId] == nil
					if firstDraw then
						table.insert(meshPartsToUpdate, meshPart)
					end

					drawTextureSet[originalTextureId] = true

					local projectedStickerActionMetadata: ImageEditActions.ProjectedStickerActionMetadata = {
						textureId = stickerData.textureId,
						targetMeshPartName = meshPart.Name,
						stickerLayerNumber = stickerData.stickerLayerNumber,
						paintLayerId = stickerData.paintLayerId,
						clearTexture = firstDraw,

						rotation = math.rad(stickerData.rotation),
						scale = stickerData.scale,

						position = meshPart.CFrame:PointToObjectSpace(stickerData.positionMarker.CFrame.Position),
						direction = meshPart.CFrame:VectorToObjectSpace(stickerData.projectionDirection),
					}

					local projectedStickerAction =
						Actions.createAction(Actions.ActionTypes.ProjectedSticker, projectedStickerActionMetadata)

					Actions.executeAction(self.modelInfo, projectedStickerAction)

					if shouldFireServer then
						Network.fire("SubmitAction", projectedStickerAction)
					else
						self.lastStickerAction = projectedStickerAction
					end
				end
			end

			local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
			for _, meshPart in meshPartsToUpdate do
				textureInfo:updateOutputColorMap(meshPart)
			end
		else
			local stickerActionMetadata: ImageEditActions.StickerActionMetadata = {
				textureId = stickerData.textureId,
				targetMeshPartName = stickerData.targetMeshPart.Name,
				stickerLayerNumber = stickerData.stickerLayerNumber,
				paintLayerId = stickerData.paintLayerId,

				position = stickerData.texturePosition,

				rotation = stickerData.rotation,
				scale = stickerData.scale,
			}

			local stickerAction = Actions.createAction(Actions.ActionTypes.Sticker, stickerActionMetadata)

			Actions.executeAction(self.modelInfo, stickerAction)

			if shouldFireServer then
				Network.fire("SubmitAction", stickerAction)
			else
				self.lastStickerAction = stickerAction
			end

			local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
			textureInfo:updateOutputColorMap(stickerData.targetMeshPart)
		end
	end

	--[=[
		@within StickerTool
		@param newPadding number -- gap between tiles
		@param isFinalInput boolean -- true on the last input of a drag, which is what mirrors to the server
	]=]
	function object:onPatternPaddingChanged(newPadding: number, isFinalInput: boolean)
		local stickerData: StickerData? = self.appliedStickers[self.currentlySelectedSticker]

		if stickerData then
			stickerData.tilePadding = newPadding
			self:redrawSticker(stickerData, isFinalInput)
		end
	end

	--[=[
		@within StickerTool

		Removes the selected sticker and its marker, then selects the one before it.
	]=]
	function object:deleteCurrentSticker()
		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if selectedSticker == nil then
			return
		end

		local removeStickerActionMetadata: ImageEditActions.RemoveStickerActionMetadata = {
			targetMeshPartName = selectedSticker.targetMeshPart.Name,
			stickerLayerNumber = selectedSticker.stickerLayerNumber,
		}

		local removeStickerAction = Actions.createAction(Actions.ActionTypes.RemoveSticker, removeStickerActionMetadata)
		Actions.executeAction(self.modelInfo, removeStickerAction)

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
		textureInfo:updateOutputColorMap(selectedSticker.targetMeshPart)

		Network.fire("SubmitAction", removeStickerAction)

		table.remove(self.appliedStickers, self.currentlySelectedSticker)

		if self.currentlySelectedSticker == #self.appliedStickers + 1 then
			self.currentlySelectedSticker = #self.appliedStickers
		end

		self.stickerCounter = self.stickerCounter - 1
		self:refreshHandleUI()
		publish()

		if selectedSticker.positionMarker then
			selectedSticker.positionMarker:Destroy()
		end
	end

	--[=[
		@within StickerTool
		@param isPatterned boolean -- whether the selected sticker tiles across its layer
	]=]
	function object:setPatterned(isPatterned: boolean)
		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if selectedSticker == nil then
			return
		end

		selectedSticker.isTiled = isPatterned
		self:redrawSticker(selectedSticker, true)
	end

	--[=[
		@within StickerTool
		@param regionName string -- the region a tiled sticker is confined to
	]=]
	function object:setSelectedRegion(regionName: string)
		if regionName and string.find(regionName, "Model") then
			self.selectedRegionName = nil
		end

		self.selectedRegionName = regionName

		self:safelyRedrawSticker()
	end

	--[=[
		@within StickerTool

		Redraws the selected sticker, if there is one.
	]=]
	function object:safelyRedrawSticker()
		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if selectedSticker ~= nil then
			self:redrawSticker(selectedSticker, true)
		end
	end

	--[=[
		@within StickerTool
		@return boolean -- true when the selected sticker is tiled
	]=]
	function object:isPatterned(): boolean
		local selectedSticker: StickerData? = self.appliedStickers[self.currentlySelectedSticker]
		if selectedSticker == nil then
			return false
		end

		return selectedSticker.isTiled
	end

	--[=[
		@within StickerTool
		@return boolean -- true when the creation carries at least one sticker
	]=]
	function object:hasAppliedStickers(): boolean
		return #self.appliedStickers > 0
	end

	--[=[
		@within StickerTool
		@param meshPart MeshPart? -- the part new stickers land on, or nil to place them in 3D again
		@param texturePosition Vector2? -- texel new stickers are centred on

		While set, [StickerTool:applySticker] places flat texture-space stickers here instead of
		projecting onto the surface nearest the camera. The 2D canvas keeps this at its view centre.
	]=]
	function object:setCanvasPlacement(meshPart: MeshPart?, texturePosition: Vector2?)
		self.canvasPlacementMeshPart = meshPart
		self.canvasPlacementPosition = texturePosition
	end

	--[=[
		@within StickerTool
		@param layerId string -- the paint layer new stickers are placed on
	]=]
	function object:setActivePaintLayer(layerId: string)
		self.activePaintLayerId = layerId
	end

	--[=[
		@within StickerTool
		@param layerId string -- the paint layer being deleted

		Drops the stickers on that layer from the tool's own bookkeeping. Their pixels are cleared
		by the RemovePaintLayer action, so no sticker actions are sent.
	]=]
	function object:forgetStickersOnLayer(layerId: string)
		for i = #self.appliedStickers, 1, -1 do
			local stickerData = self.appliedStickers[i]
			if stickerData.paintLayerId ~= layerId then
				continue
			end

			if stickerData.positionMarker then
				stickerData.positionMarker:Destroy()
			end

			table.remove(self.appliedStickers, i)
			self.stickerCounter -= 1
		end

		self.currentlySelectedSticker = math.min(self.currentlySelectedSticker, #self.appliedStickers)
		self:refreshHandleUI()
		publish()
	end

	--[=[
		@within StickerTool
		@return StickerData? -- the selected sticker, or nil when none is selected
	]=]
	function object:getSelectedSticker(): StickerData?
		return self.appliedStickers[self.currentlySelectedSticker]
	end

	--[=[
		@within StickerTool
		@param meshPart MeshPart -- the part under the new position
		@param texturePosition Vector2 -- the texel to centre the sticker on

		Moves the selected sticker in texture space. The action is held until
		[StickerTool:commitStickerEdit] so a drag only replicates once.
	]=]
	function object:moveSelectedStickerTo(meshPart: MeshPart, texturePosition: Vector2)
		local selectedSticker = self:getSelectedSticker()
		if not selectedSticker then
			return
		end

		if selectedSticker.targetMeshPart ~= meshPart then
			self:moveStickerBetweenParts(selectedSticker, meshPart)
		end

		selectedSticker.texturePosition = texturePosition
		self:redrawSticker(selectedSticker, false)
	end

	--[=[
		@within StickerTool
		@param rotation number? -- new rotation in degrees, or nil to keep it
		@param scale number? -- new scale, or nil to keep it

		Held until [StickerTool:commitStickerEdit], like a move.
	]=]
	function object:setSelectedStickerTransform(rotation: number?, scale: number?)
		local selectedSticker = self:getSelectedSticker()
		if not selectedSticker then
			return
		end

		selectedSticker.rotation = rotation or selectedSticker.rotation
		selectedSticker.scale = math.max(scale or selectedSticker.scale, 0.1)
		self:redrawSticker(selectedSticker, false)
	end

	--[=[
		@within StickerTool

		Sends the last held sticker edit to the server.
	]=]
	function object:commitStickerEdit()
		if self.lastStickerAction ~= nil then
			Network.fire("SubmitAction", self.lastStickerAction)
		end

		self.lastStickerAction = nil
	end

	--[=[
		@within StickerTool

		Shows the handles and selects the most recently applied sticker.
	]=]
	function object:enable()
		setHandleVisible(true)
		if #self.appliedStickers > 0 then
			self:selectSticker(#self.appliedStickers)
		end
		self:refreshHandleUI()
	end

	--[=[
		@within StickerTool
	]=]
	function object:disable()
		setHandleVisible(false)
		self.currentlySelectedSticker = 0
		publish()
	end

	function object:destroy()
		self.modelInfo:saveAppliedStickers(self.appliedStickers)
		self.currentlySelectedSticker = 0

		maid:doCleaning()
	end

	maid:add(UserInputService.InputChanged:Connect(function(input)
		if not ToolInput.isValidDraggingInput(input) then
			return
		end
		if object.isDragging then
			object:dragSticker(input)
		elseif object.isRotating then
			object:rotateSticker(input)
		elseif object.isScaling then
			object:scaleSticker(input)
		end
	end))

	maid:add(UserInputService.InputEnded:Connect(function(input)
		if ToolInput.isValidSelectingInput(input) then
			if object.isRotating or object.isDragging or object.isScaling then
				if object.lastStickerAction ~= nil then
					Network.fire("SubmitAction", object.lastStickerAction)
				end
			end
			object.isRotating = false
			object.isDragging = false
			object.isScaling = false
			object.lastStickerAction = nil
		end
	end))

	maid:add(workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Connect(function()
		object:refreshHandleUI()
	end))

	object:refreshHandleUI()

	for _, meshPart in modelInfo:getMeshParts() do
		maid:add(meshPart:GetPropertyChangedSignal("Position"):Connect(function()
			local selectedSticker = object.appliedStickers[object.currentlySelectedSticker]
			if selectedSticker ~= nil then
				object:refreshMarkerPosition(selectedSticker)
			end
		end))
	end

	object:disable()

	return object
end

return StickerTool

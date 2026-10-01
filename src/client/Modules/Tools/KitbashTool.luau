local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationInput = require("../CreationInput")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MeshEditActions = require(ReplicatedStorage.Shared.Modules.Actions.MeshEditActions)
local MeshUtils = require(ReplicatedStorage.Shared.Modules.Utils.MeshUtils)
local ModelDisplay = require("../ModelDisplay")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local ToolInput = require("../ToolInput")
local Types = require(ReplicatedStorage.Shared.Types)

local KitbashPieces = AssetUtil.resolve("KitbashPieces")

export type KitbashPieceData = {
	name: string,
	sourcePart: MeshPart,
	meshPart: MeshPart,
	positionMarker: Part,
	positionMarkerOffset: CFrame,
	targetMeshPart: MeshPart,
	normal: Vector3,
	rotation: number,
	scale: number,
	minScale: number,
	maxScale: number,

	isMerged: boolean,
	isMerging: boolean,
	mergedFaceIds: { number }?,
	hasDrawnToAtlas: boolean?,
	atlasSlot: number?,
}

export type KitbashTool = {
	-- vars
	pieceCount: Charm.Atom<number>,
	modelInfo: ModelInfo.ModelInfo,
	inputManager: CreationInput.CreationInput,
	modelDisplay: ModelDisplay.ModelDisplay,
	placedPieces: { KitbashPieceData },
	currentlySelectedPiece: number?,
	isDragging: boolean,
	isRotating: boolean,
	isScaling: boolean,
	mouseDownPos: Vector2?,
	handle: Charm.Atom<Types.EditHandleState>,
	maid: Maid.Maid,
	-- methods
	refreshMarkerPosition: (self: KitbashTool, selectedPiece: KitbashPieceData?) -> (),
	enable: (self: KitbashTool) -> (),
	disable: (self: KitbashTool) -> (),
	allocateAtlasSlot: (self: KitbashTool) -> number?,
	deleteCurrentPiece: (self: KitbashTool) -> (),
	refreshWrapDeformer: (self: KitbashTool, targetMeshPart: MeshPart) -> (),
	unmergePiece: (self: KitbashTool, pieceData: KitbashPieceData, isDeleting: boolean?) -> (),
	mergeCurrentPiece: (self: KitbashTool) -> (),
	beginHandleGesture: (self: KitbashTool, kind: string, input: InputObject) -> (),
	refreshHandleUI: (self: KitbashTool) -> (),
	updatePieceTransform: (self: KitbashTool, pieceData: KitbashPieceData) -> (),
	selectPiece: (self: KitbashTool, pieceName: string, minScale: number?, maxScale: number?) -> (),
	dragPiece: (self: KitbashTool, input: InputObject) -> (),
	rotatePiece: (self: KitbashTool, input: InputObject) -> (),
	scalePiece: (self: KitbashTool, input: InputObject) -> (),
	destroy: (self: KitbashTool) -> (),
}

local function getPieceData(pieceName: string)
	return {
		name = pieceName,
		sourcePart = KitbashPieces:FindFirstChild(pieceName),
	}
end

--[=[
	@class KitbashTool
	@client

	Places, edits and merges 3D pieces onto the creation. A piece is positioned on the target
	MeshPart's surface by raycast, dragged/rotated/scaled with the shared edit handles, and
	merged into the target geometry on release. Piece textures are packed into a 2x2 atlas — the
	top-left cell holds the target's own texture and each merged piece claims one of the
	remaining cells, with its UVs remapped into that cell.

	`pieceCount` tracks how many pieces are placed and `handle` places the on-screen edit handle;
	the UI renders both and forwards presses on the handle to `beginHandleGesture`.
]=]
local function KitbashTool(
	modelInfo: ModelInfo.ModelInfo,
	inputManager: CreationInput.CreationInput,
	modelDisplay: ModelDisplay.ModelDisplay
): KitbashTool
	local maid = Maid.new()
	local object = {} :: KitbashTool

	object.modelInfo = modelInfo
	object.inputManager = inputManager
	object.modelDisplay = modelDisplay

	object.placedPieces = modelInfo:getPlacedKitbashPieces()
	object.pieceCount = Charm.atom(#object.placedPieces)
	object.currentlySelectedPiece = nil
	object.isDragging = false
	object.isRotating = false
	object.isScaling = false

	object.maid = maid

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
		@within KitbashTool
		@param selectedPiece KitbashPieceData? -- the piece whose marker moved with the model
	]=]
	function object:refreshMarkerPosition(selectedPiece: KitbashPieceData?)
		if selectedPiece then
			selectedPiece.positionMarker.CFrame =
				selectedPiece.targetMeshPart.CFrame:ToWorldSpace(selectedPiece.positionMarkerOffset)

			local directionIndicator = selectedPiece.positionMarker:FindFirstChild("StickerDirectionMarker")
			if directionIndicator then
				directionIndicator.Position = selectedPiece.positionMarker.Position + selectedPiece.projectionDirection
			end

			self:refreshHandleUI()
		end
	end

	--[=[
		@within KitbashTool

		Shows the handles on the most recently placed piece, if there is one.
	]=]
	function object:enable()
		if #self.placedPieces > 0 then
			self.currentlySelectedPiece = #self.placedPieces

			setHandleVisible(true)
			self:refreshHandleUI()
		end
	end

	--[=[
		@within KitbashTool
	]=]
	function object:disable()
		setHandleVisible(false)

		self.currentlySelectedPiece = nil
		self.isDragging = false
		self.isRotating = false
		self.isScaling = false
	end

	--[=[
		@within KitbashTool
		@return number? -- the lowest free atlas cell, or nil when the atlas is full
	]=]
	function object:allocateAtlasSlot(): number?
		local usedSlots = {}
		for _, pieceData in self.placedPieces do
			if pieceData.atlasSlot then
				usedSlots[pieceData.atlasSlot] = true
			end
		end

		for i = 1, CreationConfig.atlasMaxKitbashPieces do
			if not usedSlots[i] then
				return i
			end
		end

		return nil
	end

	--[=[
		@within KitbashTool

		Removes the selected piece: unmerges its geometry, frees its atlas cell, and selects the
		piece placed before it.
	]=]
	function object:deleteCurrentPiece()
		if not self.currentlySelectedPiece then
			warn("No piece selected to delete!")
			return
		end

		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		if pieceData.isMerged then
			self:unmergePiece(pieceData, true)
		end

		pieceData.meshPart:Destroy()
		pieceData.positionMarker:Destroy()

		table.remove(self.placedPieces, self.currentlySelectedPiece)
		self.pieceCount(#self.placedPieces)

		if #self.placedPieces > 0 then
			self.currentlySelectedPiece = math.min(self.currentlySelectedPiece, #self.placedPieces)

			setHandleVisible(true)
			self:refreshHandleUI()
		else
			self.currentlySelectedPiece = nil
			setHandleVisible(false)
		end
	end

	--[=[
		@within KitbashTool
		@param targetMeshPart MeshPart -- the part whose cage should recompute

		Nudges a single cage vertex, which is what makes the WrapDeformer pick up the merged
		geometry.
	]=]
	function object:refreshWrapDeformer(targetMeshPart: MeshPart)
		local meshInfo = self.modelInfo:getMeshInfo()
		local targetMeshInfo = meshInfo:getMeshInfoByName(targetMeshPart.Name)
		if targetMeshInfo.cageInfo then
			local cageMesh = targetMeshInfo.cageInfo.cageEditableMesh
			local vertices = cageMesh:GetVertices()

			if #vertices > 0 then
				local vertexId = vertices[1]
				cageMesh:SetPosition(vertexId, cageMesh:GetPosition(vertexId))
			end
		end
	end

	--[=[
		@within KitbashTool
		@param pieceData KitbashPieceData -- the merged piece to pull back out
		@param isDeleting boolean? -- true to also free the piece's atlas cell

		Removes a piece's geometry from the target MeshPart. Unmerging also happens on every
		translate/rotate/scale, and in that case the atlas is left untouched.
	]=]
	function object:unmergePiece(pieceData: KitbashPieceData, isDeleting: boolean?)
		if not pieceData.isMerged or pieceData.isMerging then
			return
		end

		local unmergeActionMetadata: MeshEditActions.UnmergeKitbashPieceActionMetadata = {
			targetMeshPartName = pieceData.targetMeshPart.Name,
			mergedFaceIds = pieceData.mergedFaceIds,
			atlasSlot = if isDeleting then pieceData.atlasSlot else nil,
		}

		local unmergeAction = Actions.createAction(Actions.ActionTypes.UnmergeKitbashPiece, unmergeActionMetadata)
		Actions.executeAction(self.modelInfo, unmergeAction)

		self:refreshWrapDeformer(pieceData.targetMeshPart)

		Network.fire("SubmitAction", unmergeAction)

		pieceData.meshPart.Transparency = 0
		pieceData.isMerged = false
	end

	--[=[
		@within KitbashTool

		Merges the selected piece into the target MeshPart: combines the geometry, packs the
		piece texture into the atlas, and remaps the piece's UVs onto it. The merge runs locally
		first so the added face ids are known and can be removed on a later unmerge.
	]=]
	function object:mergeCurrentPiece()
		if not self.currentlySelectedPiece then
			warn("No piece selected to merge!")
			return
		end

		local pieceData = self.placedPieces[self.currentlySelectedPiece]

		if pieceData.isMerged or pieceData.isMerging then
			return
		end
		pieceData.isMerging = true
		self.modelDisplay:setRotationEnabled(false)

		local meshInfo = self.modelInfo:getMeshInfo()
		local textureInfo = self.modelInfo:getTextureInfo()

		local targetMeshPart = pieceData.targetMeshPart
		local editableMeshMap = meshInfo:getKitbashEditableMeshMap()
		local targetEditableMesh = editableMeshMap[targetMeshPart]
		local meshScaleFactorMap = meshInfo:getScaleFactorMap()
		local targetScaleFactor = meshScaleFactorMap[targetMeshPart]
		local baseTextureLayer = textureInfo:getBaseLayer(targetMeshPart)

		local addedFaceIds = MeshUtils.mergeKitbashPiece({
			targetMeshPart = targetMeshPart,
			targetEditableMesh = targetEditableMesh,
			targetScaleFactor = targetScaleFactor,
			kitbashMeshId = pieceData.sourcePart.MeshId,
			kitbashTextureId = pieceData.sourcePart.TextureID,
			positionMarkerCFrame = pieceData.positionMarker.CFrame,
			scale = pieceData.scale,
			rotation = pieceData.rotation,
			baseTextureLayer = baseTextureLayer,
			atlasSlot = pieceData.atlasSlot,
			hasDrawnToAtlas = pieceData.hasDrawnToAtlas or false,
		})

		if not pieceData.hasDrawnToAtlas then
			textureInfo:updateOutputColorMap(targetMeshPart)
		end

		self:refreshWrapDeformer(targetMeshPart)

		pieceData.mergedFaceIds = addedFaceIds

		pieceData.meshPart.Transparency = 1

		local mergeActionMetadata: MeshEditActions.MergeKitbashPieceActionMetadata = {
			targetMeshPartName = pieceData.targetMeshPart.Name,
			kitbashMeshId = pieceData.sourcePart.MeshId,
			kitbashTextureId = pieceData.sourcePart.TextureID,
			positionMarkerOffset = pieceData.positionMarkerOffset,
			scale = pieceData.scale,
			rotation = pieceData.rotation,
			atlasSlot = pieceData.atlasSlot,
			hasDrawnToAtlas = pieceData.hasDrawnToAtlas or false,
		}
		local mergeAction = Actions.createAction(Actions.ActionTypes.MergeKitbashPiece, mergeActionMetadata)
		Network.fire("SubmitAction", mergeAction)

		pieceData.hasDrawnToAtlas = true
		pieceData.isMerged = true
		pieceData.isMerging = false
		self.modelDisplay:setRotationEnabled(true)
	end

	--[=[
		@within KitbashTool
		@param kind string -- which part of the handle was pressed: `"move"`, `"rotate"` or `"scale"`
		@param input InputObject -- the press

		Starts a drag, rotate or scale gesture from the piece handle. The gesture unmerges the piece
		so it can be moved, and it merges again on release.
	]=]
	function object:beginHandleGesture(kind: string, input: InputObject)
		if not ToolInput.isValidSelectingInput(input) then
			return
		end

		if kind == "move" then
			if self.isRotating or self.isScaling or not self.inputManager:tryGrabLock(self) then
				return
			end
		elseif kind == "rotate" then
			if self.isDragging or self.isScaling or self.inputManager:tryGrabLock(self) == false then
				return
			end
		elseif kind == "scale" then
			if self.isDragging or self.isRotating or self.inputManager:tryGrabLock(self) == false then
				return
			end
		else
			return
		end

		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		if pieceData and pieceData.isMerged then
			self:unmergePiece(pieceData)
		end

		if kind == "move" then
			self.isDragging = true
		elseif kind == "rotate" then
			self.isRotating = true
		else
			self.isScaling = true

			local inputPosition = ToolInput.getInputPosition(input)
			self.mouseDownPos = Vector2.new(inputPosition.X, inputPosition.Y)
		end
	end

	--[=[
		@within KitbashTool

		Moves the handles onto the selected piece's screen position, or hides them when nothing
		is selected.
	]=]
	function object:refreshHandleUI()
		if not self.currentlySelectedPiece then
			setHandleVisible(false)
			return
		else
			setHandleVisible(true)
		end

		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		local piece3dPos = pieceData.positionMarker.Position
		local camera = workspace.CurrentCamera

		local screenPos = camera:WorldToScreenPoint(piece3dPos)

		self.handle({
			visible = true,
			offset = Vector2.new(screenPos.X, screenPos.Y),
			scale = pieceData.scale,
			rotation = pieceData.rotation,
		})
	end

	--[=[
		@within KitbashTool
		@param pieceData KitbashPieceData -- the piece to re-place

		Applies the piece's rotation and scale to its visual MeshPart.
	]=]
	function object:updatePieceTransform(pieceData: KitbashPieceData)
		local baseCFrame = pieceData.positionMarker.CFrame

		local rotationCFrame = CFrame.Angles(0, 0, math.rad(pieceData.rotation))
		local finalCFrame = baseCFrame * rotationCFrame

		local baseSize = pieceData.sourcePart.Size
		pieceData.meshPart.Size = baseSize * pieceData.scale

		pieceData.meshPart.CFrame = finalCFrame
	end

	--[=[
		@within KitbashTool
		@param pieceName string -- a MeshPart name under `ReplicatedStorage.Assets.KitbashPieces`
		@param minScale number? -- lower scale clamp, defaults to the config value
		@param maxScale number? -- upper scale clamp, defaults to the config value

		Places a new piece where a ray from the camera to the model's center lands, then merges
		it straight away.
	]=]
	function object:selectPiece(pieceName: string, minScale: number?, maxScale: number?)
		local meshInfo = self.modelInfo:getMeshInfo()
		local meshParts = self.modelInfo:getMeshParts()

		local pieceData = getPieceData(pieceName)

		if not pieceData.sourcePart then
			warn("Could not find", pieceName, "in ReplicatedStorage.Assets.KitbashPieces")
			return
		end

		local hasKitbashTexture = pieceData.sourcePart.TextureID ~= ""
		local atlasSlot = 0
		if hasKitbashTexture and not pieceData.atlasSlot then
			local slot = self:allocateAtlasSlot()
			if not slot then
				warn(
					string.format(
						"No atlas slots available! Maximum %d kitbash pieces.",
						CreationConfig.atlasMaxKitbashPieces
					)
				)
				return
			end
			atlasSlot = slot
		end

		local averagePos = Vector3.zero
		for _, part in meshParts do
			averagePos = averagePos + part.Position
		end
		averagePos = averagePos / #meshParts

		local camera = workspace.CurrentCamera
		local rayOrigin = camera.CFrame.Position
		local rayDirection = (averagePos - rayOrigin).Unit * 100

		local raycastResult = MeshUtils.raycastAll(
			Ray.new(rayOrigin, rayDirection),
			meshInfo:getEditableMeshMap(),
			meshInfo:getScaleFactorMap()
		)

		if not raycastResult then
			warn("Could not raycast to place piece - trying first mesh part")
			local firstPart = meshParts[1]
			rayDirection = (firstPart.Position - rayOrigin).Unit * 100
			raycastResult = MeshUtils.raycastAll(
				Ray.new(rayOrigin, rayDirection),
				meshInfo:getEditableMeshMap(),
				meshInfo:getScaleFactorMap()
			)

			if not raycastResult then
				warn("Could not raycast to place piece")
				return
			end
		end

		local targetMeshPart = raycastResult.meshPart

		local piece = pieceData.sourcePart:Clone()
		piece.Name = "KitbashPiece_" .. pieceData.name
		piece.CanCollide = false
		piece.Anchored = true
		piece.Transparency = 0

		local positionMarker = Create("Part", {
			Name = "KitbashPositionMarker",
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
			Parent = workspace,
		}) :: Part

		local markerCFrame = MeshUtils.editableMeshRaycastToCFrame(
			raycastResult.editableMesh,
			raycastResult.meshPart,
			raycastResult.point,
			raycastResult.triangleId,
			raycastResult.scaleFactor
		)

		positionMarker.CFrame = markerCFrame
		piece.Parent = workspace

		local newPieceData: KitbashPieceData = {
			name = pieceData.name,
			sourcePart = pieceData.sourcePart,
			meshPart = piece,
			positionMarker = positionMarker,
			positionMarkerOffset = targetMeshPart.CFrame:ToObjectSpace(markerCFrame),
			targetMeshPart = targetMeshPart,
			normal = markerCFrame.LookVector,
			rotation = 0,
			scale = 1,
			minScale = minScale or CreationConfig.defaultKitbashMinScale,
			maxScale = maxScale or CreationConfig.defaultKitbashMaxScale,
			isMerged = false,
			isMerging = false,
			atlasSlot = atlasSlot,
		}

		self:updatePieceTransform(newPieceData)
		table.insert(self.placedPieces, newPieceData)
		self.pieceCount(#self.placedPieces)
		self.currentlySelectedPiece = #self.placedPieces
		self:refreshHandleUI()
		self:mergeCurrentPiece()
	end

	--[=[
		@within KitbashTool
		@param input InputObject -- the drag input

		Moves the selected piece to wherever the drag ray hits the model.
	]=]
	function object:dragPiece(input: InputObject)
		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		if not pieceData then
			return
		end

		local inputPosition = ToolInput.getInputPosition(input)
		local ray = workspace.CurrentCamera:ScreenPointToRay(inputPosition.X, inputPosition.Y, 1)

		local meshInfo = self.modelInfo:getMeshInfo()
		local raycastResult = MeshUtils.raycastAll(ray, meshInfo:getEditableMeshMap(), meshInfo:getScaleFactorMap())

		if not raycastResult then
			return
		end

		local newCFrame = MeshUtils.editableMeshRaycastToCFrame(
			raycastResult.editableMesh,
			raycastResult.meshPart,
			raycastResult.point,
			raycastResult.triangleId,
			raycastResult.scaleFactor
		)

		pieceData.positionMarker.CFrame = newCFrame
		pieceData.positionMarkerOffset = raycastResult.meshPart.CFrame:ToObjectSpace(newCFrame)
		pieceData.targetMeshPart = raycastResult.meshPart
		pieceData.normal = newCFrame.LookVector

		self:updatePieceTransform(pieceData)
		self:refreshHandleUI()
	end

	--[=[
		@within KitbashTool
		@param input InputObject -- the drag input

		Spins the selected piece to follow the cursor around its marker.
	]=]
	function object:rotatePiece(input: InputObject)
		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		if not pieceData then
			return
		end

		local camera = workspace.CurrentCamera
		local centerScreenPos = camera:WorldToScreenPoint(pieceData.positionMarker.Position)
		local centerPos = Vector2.new(centerScreenPos.X, centerScreenPos.Y)

		local inputPosition = ToolInput.getInputPosition(input)
		local mousePos = Vector2.new(inputPosition.X, inputPosition.Y)

		local deltaPos = mousePos - centerPos
		local angle = math.deg(math.atan2(deltaPos.Y, deltaPos.X))

		pieceData.rotation = angle + 90 - StyleTokens.style.RotateHandlePosDegrees

		self:updatePieceTransform(pieceData)
		self:refreshHandleUI()
	end

	--[=[
		@within KitbashTool
		@param input InputObject -- the drag input

		Scales the selected piece by horizontal drag distance, inverted while the scale handle
		has swung round to the left of the piece.
	]=]
	function object:scalePiece(input: InputObject)
		local LEFT_POSITION_MIN_ANGLE = 45
		local LEFT_POSITION_MAX_ANGLE = 225

		local pieceData = self.placedPieces[self.currentlySelectedPiece]
		if not pieceData then
			return
		end

		local inputPosition = ToolInput.getInputPosition(input)
		local currentMousePos = Vector2.new(inputPosition.X, inputPosition.Y)
		if not self.mouseDownPos then
			self.mouseDownPos = currentMousePos
			return
		end

		local mouseMovement = currentMousePos - self.mouseDownPos
		local scaleChange = mouseMovement.X * CreationConfig.scaleDragSensitivity
		if pieceData.rotation < LEFT_POSITION_MAX_ANGLE and pieceData.rotation >= LEFT_POSITION_MIN_ANGLE then
			scaleChange *= -1
		end
		pieceData.scale = math.clamp(pieceData.scale + scaleChange, pieceData.minScale, pieceData.maxScale)
		self.mouseDownPos = currentMousePos

		self:updatePieceTransform(pieceData)
		self:refreshHandleUI()
	end

	function object:destroy()
		self.modelInfo:savePlacedKitbashPieces(self.placedPieces)

		maid:doCleaning()

		self.placedPieces = {}
	end

	maid:add(UserInputService.InputChanged:Connect(function(input)
		if object.isDragging and ToolInput.isValidDraggingInput(input) then
			object:dragPiece(input)
		elseif object.isRotating and ToolInput.isValidDraggingInput(input) then
			object:rotatePiece(input)
		elseif object.isScaling and ToolInput.isValidDraggingInput(input) then
			object:scalePiece(input)
		end
	end))

	maid:add(UserInputService.InputEnded:Connect(function(input)
		if ToolInput.isValidSelectingInput(input) then
			if object.isDragging then
				object.isDragging = false
				object:mergeCurrentPiece()
			elseif object.isRotating then
				object.isRotating = false
				object:mergeCurrentPiece()
			elseif object.isScaling then
				object.isScaling = false
				object:mergeCurrentPiece()
			end
		end
	end))

	maid:add(workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Connect(function()
		object:refreshHandleUI()
	end))

	for _, meshPart in modelInfo:getMeshParts() do
		maid:add(meshPart:GetPropertyChangedSignal("Position"):Connect(function()
			local selectedPiece = object.placedPieces[object.currentlySelectedPiece]
			if selectedPiece ~= nil then
				object:refreshMarkerPosition(selectedPiece)
			end
		end))
	end

	return object
end

return KitbashTool

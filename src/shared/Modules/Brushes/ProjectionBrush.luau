local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local GeometryUtil = require("../Utils/GeometryUtil")
local ImageEditActions = require("../Actions/ImageEditActions")
local TextureInfo = require("../TextureInfo")
local TextureUtils = require("../Utils/TextureUtils")

local MAX_BATCHED_DRAW_POSITIONS = 30

type DrawInfo = {
	textureDrawPosition: Vector2,
	cameraCFrame: CFrame,
	castedPoint: Vector3,
	isVirtualCursorMovement: boolean,
}

export type PbrMaps = {
	roughnessMap: EditableImage,
	metalnessMap: EditableImage,
	normalMap: EditableImage,
}

export type ProjectionBrush = {
	-- vars
	penSize: number,
	penColor: Color3,
	penTransparency: number,
	isReflectiveMode: boolean,
	colorBlendType: Enum.ImageCombineType,
	alphaBlendType: Enum.ImageAlphaType,
	currentMeshPart: MeshPart?,
	allMeshPart: { [MeshPart]: EditableMesh }?,
	textureInfo: TextureInfo.TextureInfo,
	targetEditableImage: EditableImage,
	roughnessMap: EditableImage,
	metalnessMap: EditableImage,
	normalMap: EditableImage,
	isPenDown: boolean,
	drawPositions: { Vector3 },
	drawCamCFrame: CFrame?,
	lastCastedPoint: Vector3?,
	intermediateEditableImage: EditableImage?,
	cachedTargetBuffer: buffer?,
	commitBrushStrokeCallback: ((ImageEditActions.ProjectionBrushActionMetadata) -> ())?,
	currentState: number?,
	-- methods
	setColor: (self: ProjectionBrush, newColor: Color3) -> (),
	setSize: (self: ProjectionBrush, newSize: number) -> (),
	setTransparency: (self: ProjectionBrush, newTransparency: number) -> (),
	setIsReflective: (self: ProjectionBrush, isReflectiveMode: boolean) -> (),
	setCurrentMeshPart: (self: ProjectionBrush, meshPart: MeshPart) -> (),
	setColorBlendType: (self: ProjectionBrush, colorBlendType: Enum.ImageCombineType) -> (),
	setAlphaBlendType: (self: ProjectionBrush, alphaBlendType: Enum.ImageAlphaType) -> (),
	setAllMeshPart: (self: ProjectionBrush, allMeshPart: { [MeshPart]: EditableMesh }) -> (),
	setState: (self: ProjectionBrush, state: number) -> (),
	setCommitBrushStrokeCallback: (
		self: ProjectionBrush,
		callback: (ImageEditActions.ProjectionBrushActionMetadata) -> ()
	) -> (),
	getRequireLocalExecute: (self: ProjectionBrush) -> boolean,
	doDraw: (self: ProjectionBrush, drawInfo: DrawInfo) -> (),
	penDown: (self: ProjectionBrush, drawInfo: DrawInfo) -> (),
	movePen: (self: ProjectionBrush, drawInfo: DrawInfo) -> (),
	penUp: (self: ProjectionBrush) -> (),
	commitCurrentDrawing: (self: ProjectionBrush) -> (),
	destroy: (self: ProjectionBrush) -> (),
}

--[=[
	@class ProjectionBrush

	Paint brush that projects the stroke from the camera onto every mesh it overlaps, so a single
	drag paints across seams and across parts rather than in the texture space of one part.
]=]
local function ProjectionBrush(
	targetEditableImage: EditableImage,
	textureInfo: TextureInfo.TextureInfo,
	pbrMaps: PbrMaps
): ProjectionBrush
	local object = {} :: ProjectionBrush

	object.penSize = 1
	object.penColor = Color3.new()
	object.penTransparency = 0
	object.isReflectiveMode = false

	object.colorBlendType = Enum.ImageCombineType.BlendSourceOver
	object.alphaBlendType = Enum.ImageAlphaType.Default

	object.currentMeshPart = nil
	object.allMeshPart = nil
	object.textureInfo = textureInfo

	object.targetEditableImage = targetEditableImage
	object.roughnessMap = pbrMaps.roughnessMap
	object.metalnessMap = pbrMaps.metalnessMap
	object.normalMap = pbrMaps.normalMap

	object.isPenDown = false

	object.drawPositions = {}
	object.drawCamCFrame = nil

	object.commitBrushStrokeCallback = nil

	object.currentState = nil

	--[=[
		@within ProjectionBrush
		@param newColor Color3 -- the color painted from now on
	]=]
	function object:setColor(newColor: Color3)
		self.penColor = newColor
	end

	--[=[
		@within ProjectionBrush
		@param newSize number -- brush size in texture pixels, scaled down to studs internally
	]=]
	function object:setSize(newSize: number)
		self.penSize = newSize * 0.01
	end

	--[=[
		@within ProjectionBrush
		@param newTransparency number -- 0 is opaque, 1 is invisible
	]=]
	function object:setTransparency(newTransparency: number)
		self.penTransparency = newTransparency
	end

	--[=[
		@within ProjectionBrush
		@param isReflectiveMode boolean -- true paints the reflective metal/roughness pair
	]=]
	function object:setIsReflective(isReflectiveMode: boolean)
		self.isReflectiveMode = isReflectiveMode
	end

	--[=[
		@within ProjectionBrush
		@param meshPart MeshPart -- the part the stroke is recorded relative to
	]=]
	function object:setCurrentMeshPart(meshPart: MeshPart)
		self.currentMeshPart = meshPart
	end

	--[=[
		@within ProjectionBrush
		@param colorBlendType Enum.ImageCombineType -- how the brush color combines with the target
	]=]
	function object:setColorBlendType(colorBlendType: Enum.ImageCombineType)
		self.colorBlendType = colorBlendType
	end

	--[=[
		@within ProjectionBrush
		@param alphaBlendType Enum.ImageAlphaType -- Default paints, Overwrite erases
	]=]
	function object:setAlphaBlendType(alphaBlendType: Enum.ImageAlphaType)
		self.alphaBlendType = alphaBlendType
	end

	--[=[
		@within ProjectionBrush
		@param allMeshPart { [MeshPart]: EditableMesh } -- every part the projection may hit
	]=]
	function object:setAllMeshPart(allMeshPart: { [MeshPart]: EditableMesh })
		self.allMeshPart = allMeshPart
	end

	--[=[
		@within ProjectionBrush
		@param state number -- a `CreationConfig.paintStates` value
	]=]
	function object:setState(state: number)
		self.currentState = state
	end

	--[=[
		@within ProjectionBrush
		@param callback (ImageEditActions.ProjectionBrushActionMetadata) -> () -- receives each committed batch so it can be turned into an action
	]=]
	function object:setCommitBrushStrokeCallback(callback: (ImageEditActions.ProjectionBrushActionMetadata) -> ())
		self.commitBrushStrokeCallback = callback
	end

	--[=[
		@within ProjectionBrush
		@return boolean -- false, the committed action only runs on the server
	]=]
	function object:getRequireLocalExecute(): boolean
		return false
	end

	--[=[
		@within ProjectionBrush
		@private
		@param drawInfo DrawInfo -- where the pen is and where the camera is looking from
	]=]
	function object:doDraw(drawInfo: DrawInfo)
		local castedPoint = drawInfo.castedPoint

		if self.lastCastedPoint == nil then
			self.lastCastedPoint = castedPoint
		end

		local sourceAlpha = self.alphaBlendType == Enum.ImageAlphaType.Default and 1.0 or 0.0
		local targetAlpha = self.alphaBlendType == Enum.ImageAlphaType.Default and 0.0 or 1.0

		local projectionBrushCircleTexture, projectionBrushLineTexture, circleBrushConfig, lineBrushConfig =
			TextureUtils.createAndSetupProjectionBrushTexturesAndConfigs(
				sourceAlpha,
				targetAlpha,
				self.penColor,
				self.colorBlendType,
				self.alphaBlendType
			)

		local isPainting = self.currentState == CreationConfig.paintStates.painting
		local pbrInfo, pbrBrushTextures = TextureUtils.generatePBRInfo(
			not isPainting,
			self.isReflectiveMode,
			self.roughnessMap,
			self.metalnessMap,
			self.normalMap
		)

		local cameraCFrame = drawInfo.cameraCFrame
		local cameraDirection = cameraCFrame.LookVector

		local scaledBrushSize = self.penSize

		local pbResult =
			TextureUtils.generateProjectionBrushPoints(self.lastCastedPoint, castedPoint, cameraCFrame, scaledBrushSize)

		local imageToDrawOn = if isPainting then self.intermediateEditableImage else self.targetEditableImage
		local allMeshPart = assert(self.allMeshPart, "ProjectionBrush has no mesh parts to project onto")
		for currMeshPart, currEditableMesh in allMeshPart do
			local collisionTest =
				GeometryUtil.testObbCollision(currMeshPart, pbResult.projectorCFrame, pbResult.projectorBrushSize)
			if collisionTest then
				TextureUtils.drawProjectionBrush(
					cameraDirection,
					currMeshPart,
					currEditableMesh,
					pbResult.castedPointOffSet,
					pbResult.castedCenterPointOffSet,
					scaledBrushSize,
					pbResult.castedDeltaVecLength,
					pbResult.castedUp,
					circleBrushConfig,
					lineBrushConfig,
					imageToDrawOn,
					pbrInfo
				)
			end
		end

		-- Painting with transparency goes through an intermediate image that the alpha is applied
		-- to once, so the stroke keeps a consistent transparency instead of compounding it.
		if isPainting then
			local intermediateEditableImage =
				assert(self.intermediateEditableImage, "ProjectionBrush has no intermediate image")
			local tempEditableImageBuffer =
				intermediateEditableImage:ReadPixelsBuffer(Vector2.zero, intermediateEditableImage.Size)
			TextureUtils.applyAlpha(intermediateEditableImage, 1 - self.penTransparency)
			self.targetEditableImage:WritePixelsBuffer(
				Vector2.zero,
				self.targetEditableImage.Size,
				self.cachedTargetBuffer
			)
			self.targetEditableImage:DrawImage(
				Vector2.zero,
				intermediateEditableImage,
				Enum.ImageCombineType.BlendSourceOver
			)
			intermediateEditableImage:WritePixelsBuffer(
				Vector2.zero,
				intermediateEditableImage.Size,
				tempEditableImageBuffer
			)
		end

		self.lastCastedPoint = castedPoint

		local currentMeshPart = assert(self.currentMeshPart, "ProjectionBrush has no current MeshPart")
		self.drawPositions[#self.drawPositions + 1] = currentMeshPart.CFrame:PointToObjectSpace(castedPoint)
		self.drawCamCFrame = currentMeshPart.CFrame:ToObjectSpace(cameraCFrame)

		projectionBrushLineTexture:Destroy()
		projectionBrushCircleTexture:Destroy()

		for _, pbrBrushTexture in pbrBrushTextures do
			pbrBrushTexture:Destroy()
		end
	end

	--[=[
		@within ProjectionBrush
		@param drawInfo DrawInfo -- where the stroke starts
	]=]
	function object:penDown(drawInfo: DrawInfo)
		self.isPenDown = true

		self.intermediateEditableImage = AssetService:CreateEditableImage({
			Size = self.targetEditableImage.Size,
		})

		-- The pre-stroke pixels are re-applied before every merge so the stroke's transparency is
		-- only ever applied once.
		self.cachedTargetBuffer = self.targetEditableImage:ReadPixelsBuffer(Vector2.zero, self.targetEditableImage.Size)

		self:doDraw(drawInfo)
	end

	--[=[
		@within ProjectionBrush
		@param drawInfo DrawInfo -- where the pen moved to
	]=]
	function object:movePen(drawInfo: DrawInfo)
		if not self.isPenDown then
			self:penDown(drawInfo)
			return
		end

		self:doDraw(drawInfo)

		if #self.drawPositions > MAX_BATCHED_DRAW_POSITIONS then
			self:commitCurrentDrawing()
		end
	end

	--[=[
		@within ProjectionBrush
	]=]
	function object:penUp()
		if not self.isPenDown then
			return
		end
		self.isPenDown = false

		self:commitCurrentDrawing()

		if self.intermediateEditableImage then
			self.intermediateEditableImage:Destroy()
			self.intermediateEditableImage = nil
		end

		self.cachedTargetBuffer = nil
		self.lastCastedPoint = nil
	end

	--[=[
		@within ProjectionBrush
		@private

		Hands the batched points to the commit callback. Called mid-stroke as well as on pen up,
		which is what keeps a long drag from turning into one huge action.
	]=]
	function object:commitCurrentDrawing()
		local currentMeshPart = assert(self.currentMeshPart, "ProjectionBrush has no current MeshPart")
		local intermediateEditableImage =
			assert(self.intermediateEditableImage, "ProjectionBrush has no intermediate image")
		local projectionBrushActionMetadata: ImageEditActions.ProjectionBrushActionMetadata = {
			referenceMeshPartName = currentMeshPart.Name,
			brushColor = self.penColor,
			brushSize = self.penSize,
			colorBlendType = self.colorBlendType,
			alphaBlendType = self.alphaBlendType,
			cameraCFrame = self.drawCamCFrame,
			drawPositions = self.drawPositions,
			isReflectiveMode = self.isReflectiveMode,
			brushTransparency = 1 - self.penTransparency,
			intermediateEditableImageBuffer = intermediateEditableImage:ReadPixelsBuffer(
				Vector2.zero,
				intermediateEditableImage.Size
			),
			cachedTargetImageBuffer = self.cachedTargetBuffer,
		}

		self.drawPositions = {}

		local commitBrushStrokeCallback =
			assert(self.commitBrushStrokeCallback, "ProjectionBrush has no commit callback")
		commitBrushStrokeCallback(projectionBrushActionMetadata)
	end

	function object:destroy()
		if self.intermediateEditableImage then
			self.intermediateEditableImage:Destroy()
			self.intermediateEditableImage = nil
		end
	end

	return object
end

return ProjectionBrush

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)

export type CameraManager = {
	-- vars
	maid: Maid.Maid,
	isLocked: boolean,
	model: Model,
	creationType: string,
	modelCFrame: CFrame,
	initialLookVector: Vector3,
	initialDistance: number,
	modelExtentsSize: Vector3,
	cameraDistance: number,
	cameraDegreesAngle: Vector2,
	cameraPanInPixels: Vector2,
	-- methods
	getCameraDistance: (self: CameraManager, fov: number, extentsSize: Vector3) -> number,
	setCameraInputLocked: (self: CameraManager, shouldLock: boolean) -> (),
	focusCameraOnParts: (self: CameraManager, affectedMeshParts: { BasePart }, position: Vector3) -> (),
	zoomToPoint: (self: CameraManager, zoomDelta: number, screenPixelPoint: Vector2?, useTouchStep: boolean?) -> (),
	calculateNewCFrame: (self: CameraManager) -> CFrame,
	updateCameraPosition: (self: CameraManager) -> (),
	resetCamera: (self: CameraManager, useTween: boolean?) -> (),
	pointsToPixelsRatio: (self: CameraManager) -> number,
	pixelsToPointsRatio: (self: CameraManager) -> number,
	clampValues: (self: CameraManager) -> (),
	panByPixels: (self: CameraManager, pixelDelta: Vector2) -> (),
	panX: (self: CameraManager, panFromCenterX: number) -> (),
	panToLeft: (self: CameraManager, isMobile: boolean?) -> (),
	destroy: (self: CameraManager) -> (),
}

local function getMinCameraDistance(creationType: string): number
	if creationType == CreationConfig.creationTypes.accessory then
		return CreationConfig.camera.minAccessoryDistance
	end

	return CreationConfig.camera.minDistance
end

--[=[
	@class CameraManager
	@client

	Frames the creation being edited: zoom, pan and focus of `workspace.CurrentCamera`, in
	pixel space so panning matches what the player drags on screen.
]=]
local function CameraManager(modelInfo: ModelInfo.ModelInfo): CameraManager
	local maid = Maid.new()
	local object = {} :: CameraManager

	local function tweenCamera(newCFrame: CFrame)
		local tween =
			TweenService:Create(workspace.CurrentCamera, CreationConfig.camera.tweenInfo, { CFrame = newCFrame })
		maid.cameraTween = tween
		tween:Play()
	end

	object.maid = maid
	object.isLocked = false
	object.model = modelInfo:getModel()
	object.creationType = modelInfo:getCreationType()
	object.modelCFrame = modelInfo:getInitialModelCFrame()
	object.initialLookVector = object.modelCFrame.LookVector

	--[=[
		@within CameraManager
		@param fov number -- vertical field of view, in degrees
		@param extentsSize Vector3 -- size of what has to fit on screen
		@return number -- camera distance, clamped to the creation type's limits
	]=]
	function object:getCameraDistance(fov: number, extentsSize: Vector3): number
		local xSize, ySize, zSize = extentsSize.X, extentsSize.Y, extentsSize.Z

		local maxSize = math.max(xSize, ySize)

		local fovMultiplier = 1 / math.tan(math.rad(fov) / 2)
		local halfSize = maxSize / 2
		local distance = (halfSize * fovMultiplier) + (zSize / 2)
		if ySize < 3.0 then
			distance = distance * CreationConfig.camera.accessoryDistanceScale
		end

		local minCameraDistance = getMinCameraDistance(self.creationType)
		return math.clamp(distance, minCameraDistance, CreationConfig.camera.maxDistance)
	end

	--[=[
		@within CameraManager
		@param shouldLock boolean -- true while another interaction owns the camera
	]=]
	function object:setCameraInputLocked(shouldLock: boolean)
		self.isLocked = shouldLock
	end

	--[=[
		@within CameraManager
		@param affectedMeshParts { BasePart } -- the parts that should fill the frame
		@param position Vector3 -- world point to center on
	]=]
	function object:focusCameraOnParts(affectedMeshParts: { BasePart }, position: Vector3)
		local newPan = (position - self.modelCFrame.Position) * self:pointsToPixelsRatio()
		self.cameraPanInPixels = Vector2.new(newPan.X, newPan.Y)

		local tempModel = Instance.new("Model")
		for _, meshPart in affectedMeshParts do
			meshPart:Clone().Parent = tempModel
		end
		local affectedPartsExtentsSize = tempModel:GetExtentsSize()
		tempModel:Destroy()

		self.cameraDistance = self:getCameraDistance(CreationConfig.camera.fieldOfView, affectedPartsExtentsSize)
		tweenCamera(self:calculateNewCFrame())
	end

	--[=[
		@within CameraManager
		@param zoomDelta number -- scroll or pinch delta
		@param screenPixelPoint Vector2? -- point to keep stationary while zooming
		@param useTouchStep boolean? -- true for pinch input, which uses a finer step
	]=]
	function object:zoomToPoint(zoomDelta: number, screenPixelPoint: Vector2?, useTouchStep: boolean?)
		if self.isLocked then
			return
		end

		local prevCameraDistance = self.cameraDistance
		local step = if useTouchStep
			then CreationConfig.camera.touchZoomStep * zoomDelta
			else CreationConfig.camera.scrollZoomStep * zoomDelta

		step = step * (self.cameraDistance / self.initialDistance)
		self.cameraDistance = self.cameraDistance + step
		self:clampValues()

		if screenPixelPoint and prevCameraDistance ~= self.cameraDistance then
			local screenCenterPoint =
				Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
			local scalingFactor = (step / self.cameraDistance * Vector2.new(-1, 1))
			self.cameraPanInPixels = self.cameraPanInPixels + (screenPixelPoint - screenCenterPoint) * scalingFactor
			self:clampValues()
		end

		self:updateCameraPosition()
	end

	--[=[
		@within CameraManager
		@return CFrame -- camera CFrame for the current zoom and pan
	]=]
	function object:calculateNewCFrame(): CFrame
		local newCFrame = CFrame.new(
			self.modelCFrame.Position + (self.initialLookVector * self.cameraDistance),
			self.modelCFrame.Position
		)

		local panScalingFactor = self:pixelsToPointsRatio()

		return newCFrame
			+ newCFrame.UpVector * panScalingFactor * self.cameraPanInPixels.Y
			+ newCFrame.RightVector * panScalingFactor * self.cameraPanInPixels.X
	end

	--[=[
		@within CameraManager

		Applies the current zoom and pan to the camera without a tween.
	]=]
	function object:updateCameraPosition()
		if workspace.CurrentCamera.ViewportSize == nil or self.cameraDistance == nil then
			warn("absoluteSize or cameraDistance were not defined!")
			return
		end

		local camera = workspace.CurrentCamera
		camera.CFrame = self:calculateNewCFrame()
		camera.Focus = self.modelCFrame
	end

	--[=[
		@within CameraManager
		@param useTween boolean? -- tween to the framing instead of snapping to it
	]=]
	function object:resetCamera(useTween: boolean?)
		local model = self.model
		if not model then
			error("Camera Manager did not find a model!")
		end

		local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			self.initialLookVector = (humanoidRootPart :: BasePart).CFrame.LookVector
		end

		self.modelExtentsSize = model:GetExtentsSize()
		self.cameraDistance = self:getCameraDistance(CreationConfig.camera.fieldOfView, self.modelExtentsSize)

		self.cameraDegreesAngle = Vector2.new(0, 0)

		self.cameraPanInPixels = Vector2.new(0, 0)

		if useTween then
			tweenCamera(self:calculateNewCFrame())
		else
			self:updateCameraPosition()
		end
	end

	--[=[
		@within CameraManager
		@return number -- pixels per world stud at the current viewport size

		The viewport only scales its contents by height, so the ratio is derived from the
		viewport height against the largest horizontal or vertical model extent.
	]=]
	function object:pointsToPixelsRatio(): number
		local absoluteSize = workspace.CurrentCamera.ViewportSize
		if
			absoluteSize == nil
			or self.modelExtentsSize == nil
			or absoluteSize.Y == 0
			or self.modelExtentsSize.Y == 0
			or self.modelExtentsSize.X == 0
		then
			return 1
		end

		return workspace.CurrentCamera.ViewportSize.Y / math.max(self.modelExtentsSize.X, self.modelExtentsSize.Y)
	end

	--[=[
		@within CameraManager
		@return number -- world studs per pixel at the current viewport size
	]=]
	function object:pixelsToPointsRatio(): number
		local absoluteSize = workspace.CurrentCamera.ViewportSize
		if
			absoluteSize == nil
			or self.modelExtentsSize == nil
			or absoluteSize.Y == 0
			or self.modelExtentsSize.Y == 0
			or self.modelExtentsSize.X == 0
		then
			return 1
		end

		return math.max(self.modelExtentsSize.X, self.modelExtentsSize.Y) / workspace.CurrentCamera.ViewportSize.Y
	end

	--[=[
		@within CameraManager

		Clamps pan so the model's extent never travels past the center of the frame, and clamps
		zoom to the creation type's distance limits.
	]=]
	function object:clampValues()
		local absoluteSize = workspace.CurrentCamera.ViewportSize
		local maxPanFromCenterX = math.max(self.modelExtentsSize.X / 2 / self:pixelsToPointsRatio(), absoluteSize.X / 2)
		local maxPanFromCenterY = math.max(self.modelExtentsSize.Y / 2 / self:pixelsToPointsRatio(), absoluteSize.Y / 2)
		self.cameraPanInPixels = Vector2.new(
			math.clamp(self.cameraPanInPixels.X, -maxPanFromCenterX, maxPanFromCenterX),
			math.clamp(self.cameraPanInPixels.Y, -maxPanFromCenterY, maxPanFromCenterY)
		)

		self.cameraDistance =
			math.clamp(self.cameraDistance, getMinCameraDistance(self.creationType), CreationConfig.camera.maxDistance)
	end

	--[=[
		@within CameraManager
		@param pixelDelta Vector2 -- pan delta in screen pixels
	]=]
	function object:panByPixels(pixelDelta: Vector2)
		if self.isLocked then
			return
		end

		self.cameraPanInPixels = self.cameraPanInPixels + pixelDelta
		self:clampValues()
		self:updateCameraPosition()
	end

	--[=[
		@within CameraManager
		@param panFromCenterX number -- horizontal offset from center, in pixels
	]=]
	function object:panX(panFromCenterX: number)
		local model = self.model
		if not model then
			error("Camera Manager did not find a model!")
		end

		local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			self.initialLookVector = (humanoidRootPart :: BasePart).CFrame.LookVector
		end

		self.modelExtentsSize = model:GetExtentsSize()
		self.cameraDistance = self:getCameraDistance(CreationConfig.camera.fieldOfView, self.modelExtentsSize)

		self.cameraDegreesAngle = Vector2.new(0, 0)

		self.cameraPanInPixels = Vector2.new(panFromCenterX, 0)

		tweenCamera(self:calculateNewCFrame())
	end

	--[=[
		@within CameraManager
		@param isMobile boolean? -- true on a mobile viewport, which needs a wider offset

		Moves the creation to about a fourth from the left edge so the editing panel has room.
	]=]
	function object:panToLeft(isMobile: boolean?)
		local absoluteSize = workspace.CurrentCamera.ViewportSize
		local panFromCenterX = absoluteSize.X / 2 - absoluteSize.X / 4

		if self.creationType == CreationConfig.creationTypes.accessory and isMobile then
			panFromCenterX *= CreationConfig.camera.mobileAccessoryPanXOffsetScale
		end

		self:panX(panFromCenterX)

		if self.creationType == CreationConfig.creationTypes.accessory then
			self.cameraDistance = math.max(
				getMinCameraDistance(self.creationType),
				self.cameraDistance * CreationConfig.camera.accessoryZoom
			)

			tweenCamera(self:calculateNewCFrame())
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	object.initialDistance = object:getCameraDistance(CreationConfig.camera.fieldOfView, object.model:GetExtentsSize())
	object:resetCamera()

	return object
end

return CameraManager

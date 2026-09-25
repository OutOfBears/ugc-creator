local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)

export type ModelDisplay = {
	-- vars
	model: Model,
	creationType: string,
	enableYRotation: boolean,
	rotationEnabled: boolean,
	rotationX: number,
	rotationY: number,
	positionOffset: Vector3,
	originalCFrame: CFrame,
	localFocusPoint: Vector3,
	globalFocusPoint: Vector3,
	defaultCameraCFrame: CFrame,
	previewModels: { Model }?,
	-- methods
	setRotationEnabled: (self: ModelDisplay, enabled: boolean) -> (),
	trackPreviewModels: (self: ModelDisplay, previewModels: { Model }) -> (),
	resetModel: (self: ModelDisplay) -> (),
	getNearestSnapAngle: (self: ModelDisplay) -> number,
	getCurrentView: (self: ModelDisplay) -> string,
	updateModelCFrames: (self: ModelDisplay) -> (),
	getModel: (self: ModelDisplay) -> Model,
	setRotationY: (self: ModelDisplay, rotationY: number) -> (),
	rotateModelFromPixels: (self: ModelDisplay, deltaX: number, deltaY: number) -> (),
	rotateModelFromDegrees: (self: ModelDisplay, degreesX: number, degreesY: number) -> (),
	getScreenPosition: (self: ModelDisplay) -> Vector2,
	rotateModel: (self: ModelDisplay) -> (),
	onExitedEditMode: (self: ModelDisplay) -> (),
	destroy: (self: ModelDisplay) -> (),
}

--[=[
	@class ModelDisplay
	@client

	Holds the orientation and offset of the creation being edited, and applies them to the
	model and any preview models tracking it.
]=]
local function ModelDisplay(modelInfo: ModelInfo.ModelInfo): ModelDisplay
	local object = {} :: ModelDisplay

	object.model = modelInfo:getModel()
	object.creationType = modelInfo:getCreationType()
	object.enableYRotation = modelInfo.blank.enableYRotation
	object.rotationEnabled = true

	local isAccessory = object.creationType == CreationConfig.creationTypes.accessory
	local initialRotationX = modelInfo.blank.initialYaw or (if isAccessory then 0 else 180)
	object.rotationX = initialRotationX
	object.rotationY = 0
	object.positionOffset = Vector3.new(0, 0, -2)

	Lighting.ClockTime = 9
	Lighting.GeographicLatitude = 50

	object.originalCFrame = modelInfo:getInitialModelCFrame()
	object.localFocusPoint = Vector3.zero
	object.globalFocusPoint = object.model.PrimaryPart.CFrame.Position
	object.defaultCameraCFrame = workspace.CurrentCamera.CFrame

	--[=[
		@within ModelDisplay
		@param enabled boolean -- false while another interaction owns the drag
	]=]
	function object:setRotationEnabled(enabled: boolean)
		self.rotationEnabled = enabled
	end

	--[=[
		@within ModelDisplay
		@param previewModels { Model } -- models that should follow the creation's rotation
	]=]
	function object:trackPreviewModels(previewModels: { Model })
		self.previewModels = previewModels
		self:rotateModel()
	end

	--[=[
		@within ModelDisplay

		Returns the creation to its starting rotation and offset.
	]=]
	function object:resetModel()
		self.rotationX = initialRotationX
		self.rotationY = 0
		self.positionOffset = Vector3.new(0, 0, -2)
		self:rotateModel()
		self:updateModelCFrames()
	end

	--[=[
		@within ModelDisplay
		@return number -- the multiple of 90 degrees nearest the current rotation
	]=]
	function object:getNearestSnapAngle(): number
		local rotation = self.rotationX % 360
		local nearestSnapAngle = math.round(rotation / 90) * 90

		return nearestSnapAngle
	end

	--[=[
		@within ModelDisplay
		@return string -- "Front", "Side" or "Back", as used to pick which widgets are visible
	]=]
	function object:getCurrentView(): string
		local nearestSnapAngle = self:getNearestSnapAngle()

		if nearestSnapAngle == 180 then
			return "Front"
		elseif nearestSnapAngle == 90 or nearestSnapAngle == 270 then
			return "Side"
		else
			return "Back"
		end
	end

	--[=[
		@within ModelDisplay

		Clamps the position offset so the creation stays in frame, then applies it.
	]=]
	function object:updateModelCFrames()
		local clampedX =
			math.clamp(self.positionOffset.X, CreationConfig.display.minOffsetX, CreationConfig.display.maxOffsetX)
		local clampedY =
			math.clamp(self.positionOffset.Y, CreationConfig.display.minOffsetY, CreationConfig.display.maxOffsetY)
		local clampedZ =
			math.clamp(self.positionOffset.Z, CreationConfig.display.minOffsetZ, CreationConfig.display.maxOffsetZ)
		self.positionOffset = Vector3.new(clampedX, clampedY, clampedZ)

		local newCFrame = CFrame.new(self.originalCFrame.Position + self.positionOffset)
			* self.originalCFrame.Rotation
			* CFrame.Angles(math.rad(self.rotationY), math.rad(self.rotationX), 0)

		self.model:SetPrimaryPartCFrame(newCFrame)
	end

	--[=[
		@within ModelDisplay
		@return Model -- the creation being displayed
	]=]
	function object:getModel(): Model
		return self.model
	end

	--[=[
		@within ModelDisplay
		@param rotationY number -- absolute vertical rotation, in degrees
	]=]
	function object:setRotationY(rotationY: number)
		self.rotationY = rotationY
	end

	--[=[
		@within ModelDisplay
		@param deltaX number -- horizontal drag distance, in pixels
		@param deltaY number -- vertical drag distance, in pixels
	]=]
	function object:rotateModelFromPixels(deltaX: number, deltaY: number)
		if not self.rotationEnabled then
			return
		end

		self.rotationX += deltaX * CreationConfig.display.degreesPerPixel
		if self.enableYRotation then
			self.rotationY += deltaY * CreationConfig.display.degreesPerPixel
		end
		self:rotateModel()
	end

	--[=[
		@within ModelDisplay
		@param degreesX number -- horizontal rotation to add, in degrees
		@param degreesY number -- vertical rotation to add, in degrees
	]=]
	function object:rotateModelFromDegrees(degreesX: number, degreesY: number)
		if not self.rotationEnabled then
			return
		end

		self.rotationX += degreesX
		if self.enableYRotation then
			self.rotationY += degreesY
		end
		self:rotateModel()
	end

	--[=[
		@within ModelDisplay
		@return Vector2 -- where the creation sits on screen, in pixels
	]=]
	function object:getScreenPosition(): Vector2
		local modelWorldPosition = self.model.PrimaryPart.Position
		local vector, _onScreen = workspace.CurrentCamera:WorldToScreenPoint(modelWorldPosition)
		return Vector2.new(vector.X, vector.Y)
	end

	--[=[
		@within ModelDisplay

		Applies the current rotation, keeping the focus point where the model's center was so
		that focusing on a region does not swing it off screen.
	]=]
	function object:rotateModel()
		if self.model == nil or self.model.PrimaryPart == nil then
			return
		end
		local currentCFrame = self.model.PrimaryPart.CFrame
		local currentPos = currentCFrame.Position
		local startOrientation = self.originalCFrame.Rotation
		local newCFrame = CFrame.new(currentPos.X, currentPos.Y, currentPos.Z)
			* startOrientation
			* CFrame.Angles(math.rad(self.rotationY), math.rad(self.rotationX), 0)
		local worldSpaceOffset = (newCFrame:PointToWorldSpace(self.localFocusPoint) - newCFrame.Position)
		local modelPos = self.globalFocusPoint - worldSpaceOffset

		newCFrame = CFrame.new(modelPos.X, modelPos.Y, modelPos.Z)
			* startOrientation
			* CFrame.Angles(math.rad(self.rotationY), math.rad(self.rotationX), 0)

		self.model:SetPrimaryPartCFrame(newCFrame + self.positionOffset)

		if self.previewModels then
			for _, previewModel in self.previewModels do
				local currentPreviewCFrame = previewModel.PrimaryPart.CFrame
				local currentPreviewPos = currentPreviewCFrame.Position
				local newPreviewCFrame = CFrame.new(currentPreviewPos.X, currentPreviewPos.Y, currentPreviewPos.Z)
					* CFrame.Angles(0, math.rad(self.rotationX), 0)

				previewModel:SetPrimaryPartCFrame(newPreviewCFrame)
			end
		end
	end

	--[=[
		@within ModelDisplay

		Puts the creation back where it started and drops the focus point.
	]=]
	function object:onExitedEditMode()
		self.model:SetPrimaryPartCFrame(self.originalCFrame)
		self.localFocusPoint = Vector3.zero
		self.globalFocusPoint = self.model.PrimaryPart.CFrame.Position
		self:rotateModel()
	end

	function object:destroy()
		-- The model is owned by the ModelInfo that created it.
	end

	object:rotateModel()
	object:updateModelCFrames()

	return object
end

return ModelDisplay

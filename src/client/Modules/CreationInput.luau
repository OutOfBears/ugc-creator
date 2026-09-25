local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraManager = require("./CameraManager")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local InputContext = require("./InputContext")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelDisplay = require("./ModelDisplay")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CREATION_CONTEXT = "creation"
local GAMEPAD_ACTION_NAME = "RotateAndZoom"

type ActiveInput = {
	lastPosition: Vector3,
	lastTime: number,
	lastDeltaTime: number?,
	lastDeltaPosition: Vector3?,
}

export type CreationInput = {
	-- vars
	maid: Maid.Maid,
	screenGui: ScreenGui,
	-- methods
	tryGrabLock: (self: CreationInput, grabber: any) -> boolean,
	isLocked: (self: CreationInput) -> boolean,
	destroy: (self: CreationInput) -> (),
}

local function normalizeStickByDeadzone(stickVector: Vector2): Vector2
	local magnitude = stickVector.Magnitude
	if magnitude < CreationConfig.input.thumbstickDeadzone then
		return Vector2.new(0, 0)
	else
		return (magnitude - CreationConfig.input.thumbstickDeadzone)
			/ (1 - CreationConfig.input.thumbstickDeadzone)
			* stickVector.Unit
	end
end

local function rotateAndZoom(
	inputObject: InputObject,
	deltaTime: number,
	rotateByDegrees: ((number, number) -> ())?,
	zoomStraight: ((number) -> ())?
)
	local stickInput = normalizeStickByDeadzone(Vector2.new(inputObject.Position.X, inputObject.Position.Y))
	if stickInput == Vector2.new(0, 0) then
		return
	end

	if
		rotateByDegrees
		and (
			math.abs(stickInput.X) > CreationConfig.input.minAxisThreshold
			or math.abs(stickInput.Y) > CreationConfig.input.minAxisThreshold
		)
	then
		local radiansToDegrees = 180 / math.pi
		local degreesX = deltaTime * stickInput.X * CreationConfig.input.maxStickAngularSpeed * radiansToDegrees
		local degreesY = deltaTime * stickInput.Y * CreationConfig.input.maxStickAngularSpeed * radiansToDegrees
		rotateByDegrees(degreesX, degreesY)
	end

	if zoomStraight and math.abs(stickInput.Y) > CreationConfig.input.minAxisThreshold then
		zoomStraight(deltaTime * -stickInput.Y * CreationConfig.input.maxZoomSpeed)
	end
end

local function splitInputType(inputObject: InputObject)
	local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch
	local isMouse1 = inputObject.UserInputType == Enum.UserInputType.MouseButton1
	local isMouse2 = inputObject.UserInputType == Enum.UserInputType.MouseButton2
	local isMouseMovement = inputObject.UserInputType == Enum.UserInputType.MouseMovement
	local isGamepadPrimaryButton = inputObject.KeyCode == Enum.KeyCode.ButtonA
	local isGamepadPrimaryThumbstick = inputObject.KeyCode == Enum.KeyCode.Thumbstick1
	local isMouse = isMouse1 or isMouse2

	return isTouch, isMouse, isGamepadPrimaryButton, isGamepadPrimaryThumbstick, isMouse1, isMouse2, isMouseMovement
end

--=============================================================================
-- BINDING SEAM -- discrete key/button presses for the editor belong in
-- `ReplicatedStorage.Shared.Data.Inputs` under the "creation" context and get connected here,
-- through `InputController`'s registry. Everything below this function is gesture tracking
-- (drag, orbit, pinch-zoom, multi-touch), which the registry does not cover.
--=============================================================================
local function bindCreationContext(maid: Maid.Maid)
	InputContext.add(CREATION_CONTEXT)
	maid:giveTask(function()
		InputContext.remove(CREATION_CONTEXT)
	end)
end

--[=[
	@class CreationInput
	@client

	Captures the pointer gestures that rotate, zoom and pan the creation, and hands out a
	single input lock. The lock is what stops a fast drag that slips off a handle from being
	picked up by whatever GUI happens to sit underneath it.
]=]
local function CreationInput(
	cameraManager: CameraManager.CameraManager,
	modelDisplay: ModelDisplay.ModelDisplay
): CreationInput
	local maid = Maid.new()
	local object = {} :: CreationInput

	local locked = false
	local objectWithLock: any = nil

	local activeTouchInputs: { [InputObject]: ActiveInput } = {}
	local numActiveTouchInputs = 0
	local activeMouseInput: ActiveInput? = nil
	local numActiveInputs = 0

	local lastPinchDistance: number? = nil
	local lastDragPosition: Vector3? = nil

	local gamepadInputState: Enum.UserInputState? = nil
	local gamepadInputObject: InputObject? = nil

	local screenGui = Create("ScreenGui", {
		Name = "CameraInputCapture",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 0,
		ResetOnSpawn = false,
		Children = {
			Create("Frame", {
				Name = "InputCapture",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}),
		},
		Parent = PlayerGui,
	}) :: ScreenGui

	maid:giveTask(screenGui)

	local function getActiveInput(inputObject: InputObject): ActiveInput?
		local isTouch, isMouseButton, isGamepadButton, isGamepadThumbstick = splitInputType(inputObject)
		local isMouseMovement = inputObject.UserInputType == Enum.UserInputType.MouseMovement
		local isMouse = isMouseMovement or isMouseButton
		local isGamepad = isGamepadButton or isGamepadThumbstick

		if not (isMouse or isTouch or isGamepad) then
			return
		end

		local activeInput
		if isMouse or isGamepadButton then
			activeInput = activeMouseInput
		elseif isTouch then
			activeInput = activeTouchInputs[inputObject]
		end

		return activeInput
	end

	local onInputChanged, onInputEnded

	local function addActivePointerInput(
		inputObject: InputObject,
		isMouse: boolean,
		isGamepadButton: boolean,
		time: number
	)
		if getActiveInput(inputObject) then
			return
		end

		local activeInput: ActiveInput = {
			lastPosition = inputObject.Position,
			lastTime = time,
		}

		if isMouse or isGamepadButton then
			activeMouseInput = activeInput
		else
			activeInput.lastDeltaTime = 0
			activeInput.lastDeltaPosition = Vector3.new(0, 0, 0)
			activeTouchInputs[inputObject] = activeInput
			numActiveTouchInputs = numActiveTouchInputs + 1
		end
		numActiveInputs = numActiveInputs + 1

		if numActiveInputs == 1 then
			maid.inputChanged = UserInputService.InputChanged:Connect(onInputChanged)
			maid.inputEnded = UserInputService.InputEnded:Connect(onInputEnded)
		end
	end

	local function disconnectEvents()
		maid.inputChanged = nil
		maid.inputEnded = nil
	end

	local function removeActivePointerInput(inputObject: InputObject, isMouse: boolean, isGamepadButton: boolean)
		if isMouse or isGamepadButton then
			local allMouseButtonsReleased = not (
				UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
				or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			)

			if allMouseButtonsReleased or inputObject.UserInputType == Enum.UserInputType.Gamepad1 then
				activeMouseInput = nil
			else
				return
			end
		else
			activeTouchInputs[inputObject] = nil
			numActiveTouchInputs = numActiveTouchInputs - 1
		end
		numActiveInputs = numActiveInputs - 1

		if numActiveInputs == 0 then
			disconnectEvents()
		end
	end

	onInputChanged = function(inputObject: InputObject, gameProcessedEvent: boolean)
		if locked or gameProcessedEvent then
			return
		end
		local isTouch, _isMouse, _isGamepadButton, _isGamepadThumbstick, _isMouse1, _isMouse2, isMouseMovement =
			splitInputType(inputObject)
		local isValidInputType = isMouseMovement or isTouch

		if not isValidInputType then
			return
		end
		local activeInput = getActiveInput(inputObject)
		if not activeInput then
			return
		end
		local time = tick()
		local deltaPosition = inputObject.Position - activeInput.lastPosition
		local deltaPosition2D = Vector2.new(deltaPosition.X, deltaPosition.Y) * Vector2.new(-1, 1)
		local mouse1Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		local mouse2Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

		if isMouseMovement and mouse2Pressed or isTouch and numActiveTouchInputs == 2 then
			local averageDeltaPosition2D = deltaPosition2D / numActiveInputs
			cameraManager:panByPixels(averageDeltaPosition2D)
		elseif isMouseMovement and mouse1Pressed or isTouch and numActiveTouchInputs == 1 then
			local delta = inputObject.Delta

			if numActiveInputs == 1 then
				-- Delta is always 0 for mouse click+drag, so it has to be tracked by hand.
				if delta.Magnitude == 0 and lastDragPosition ~= nil then
					delta = inputObject.Position - lastDragPosition
					lastDragPosition = inputObject.Position
				end

				modelDisplay:rotateModelFromPixels(delta.X, -delta.Y)
			end
		end

		activeInput.lastPosition = inputObject.Position
		activeInput.lastTime = time
	end

	onInputEnded = function(inputObject: InputObject, _gameProcessedEvent: boolean)
		local isTouch, isMouse, isGamepadButton = splitInputType(inputObject)

		local isValidInputType = isTouch or isMouse or isGamepadButton

		if not isValidInputType then
			return
		end

		local activeInput = getActiveInput(inputObject)
		if not activeInput then
			return
		end

		removeActivePointerInput(inputObject, isMouse, isGamepadButton)
		if numActiveTouchInputs == 0 then
			locked = false
			objectWithLock = nil
		end
	end

	local function onInputBegan(inputObject: InputObject, _gameProcessed: boolean)
		local isTouch, isMouse, isGamepadButton, _isGamepadThumbstick, isMouse1 = splitInputType(inputObject)
		local isValidInputType = isTouch or isMouse or isGamepadButton

		if not isValidInputType then
			return
		end

		local time = tick()
		if isMouse1 or isGamepadButton then
			lastDragPosition = inputObject.Position
		end

		addActivePointerInput(inputObject, isMouse, isGamepadButton, time)
	end

	local function handleScroll(inputObject: InputObject)
		if locked then
			return
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			cameraManager:zoomToPoint(inputObject.Position.Z, UserInputService:GetMouseLocation())
		end
	end

	local function onTouchPinch(
		touchPositions: { Vector2 },
		_scale: number,
		_velocity: number,
		state: Enum.UserInputState
	)
		if locked or touchPositions[2] == nil then
			return
		end

		if state == Enum.UserInputState.Begin then
			lastPinchDistance = (touchPositions[1] - touchPositions[2]).Magnitude
			return
		end
		if not lastPinchDistance then
			return
		end

		local pinchDistance = (touchPositions[1] - touchPositions[2]).Magnitude
		local deltaPinch = pinchDistance - lastPinchDistance
		lastPinchDistance = pinchDistance
		cameraManager:zoomToPoint(deltaPinch, (touchPositions[1] + touchPositions[2]) / 2, true)

		if state == Enum.UserInputState.End then
			lastPinchDistance = nil
		end
	end

	local function storeInput(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
		gamepadInputState = inputState
		gamepadInputObject = inputObject

		return Enum.ContextActionResult.Sink
	end

	local function rotateByDegrees(degreesX: number, _degreesY: number)
		modelDisplay:rotateModelFromDegrees(degreesX, 0)
	end

	local function zoomStraight(zoomDelta: number)
		cameraManager:zoomToPoint(-zoomDelta, modelDisplay:getScreenPosition())
	end

	object.maid = maid
	object.screenGui = screenGui

	--[=[
		@within CreationInput
		@param grabber any -- the object asking to own input, usually a tool or widget manager
		@return boolean -- false if a different object already holds the lock
	]=]
	function object:tryGrabLock(grabber: any): boolean
		if locked and objectWithLock ~= grabber then
			return false
		end

		locked = true
		objectWithLock = grabber
		return true
	end

	--[=[
		@within CreationInput
		@return boolean -- true while some object holds the input lock
	]=]
	function object:isLocked(): boolean
		return locked
	end

	function object:destroy()
		maid:doCleaning()
	end

	bindCreationContext(maid)

	maid.inputBegan = UserInputService.InputBegan:Connect(onInputBegan)
	maid.scroll = (screenGui :: any).InputCapture.InputChanged:Connect(handleScroll)
	maid.touchPinch = UserInputService.TouchPinch:Connect(onTouchPinch)

	ContextActionService:UnbindAction(GAMEPAD_ACTION_NAME)
	ContextActionService:BindAction(GAMEPAD_ACTION_NAME, storeInput, false, Enum.KeyCode.Thumbstick2)
	maid:giveTask(function()
		ContextActionService:UnbindAction(GAMEPAD_ACTION_NAME)
	end)

	maid.gamepad = RunService.RenderStepped:Connect(function(deltaTime)
		if gamepadInputState == Enum.UserInputState.Change and gamepadInputObject then
			rotateAndZoom(gamepadInputObject, deltaTime, rotateByDegrees, zoomStraight)
		end
	end)

	return object
end

return CreationInput

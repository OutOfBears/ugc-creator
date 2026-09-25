local GamepadService = game:GetService("GamepadService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local GAMEPAD_INPUT_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

--[=[
	@class ToolInput
	@client

	The input predicates the editor tools share — which inputs count as a select or a drag, and
	where on screen an input actually is across mouse, touch and gamepad virtual cursor.
]=]

--[=[
	@within ToolInput
	@param userInputType Enum.UserInputType -- the type to test
	@return boolean -- true while a gamepad is driving the on-screen virtual cursor
]=]
local function isVirtualCursor(userInputType: Enum.UserInputType): boolean
	return GAMEPAD_INPUT_TYPES[userInputType] == true and GamepadService.GamepadCursorEnabled
end

--[=[
	@within ToolInput
	@param input InputObject -- the input to test
	@return boolean -- true if the input can continue a drag
]=]
local function isValidDraggingInput(input: InputObject): boolean
	return (
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseMovement
		or input.KeyCode == Enum.KeyCode.Thumbstick1
	)
end

--[=[
	@within ToolInput
	@param input InputObject -- the input to test
	@return boolean -- true if the input can begin or end a selection
]=]
local function isValidSelectingInput(input: InputObject): boolean
	return (
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonA
	)
end

--[=[
	@within ToolInput
	@param input InputObject -- the input to locate
	@return Vector2 | Vector3 -- touch inputs carry their own position; everything else reads the mouse, gui inset removed
]=]
local function getInputPosition(input: InputObject)
	local guiInset = GuiService:GetGuiInset()
	if input.UserInputType == Enum.UserInputType.Touch then
		return input.Position
	else
		return UserInputService:GetMouseLocation() - guiInset
	end
end

--[=[
	@within ToolInput
	@param input InputObject -- the input to locate
	@return Vector2 -- where the input is in the space `GuiObject.AbsolutePosition` uses, even inside an `IgnoreGuiInset` gui
]=]
local function getGuiPosition(input: InputObject): Vector2
	local inputPosition = getInputPosition(input)

	return Vector2.new(inputPosition.X, inputPosition.Y)
end

return {
	getGuiPosition = getGuiPosition,
	isVirtualCursor = isVirtualCursor,
	isValidDraggingInput = isValidDraggingInput,
	isValidSelectingInput = isValidSelectingInput,
	getInputPosition = getInputPosition,
}
